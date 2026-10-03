import SwiftUI
import UIKit
import PrivateActionCore
import OSLog

@MainActor @Observable final class AppEnvironment {
    var items: [InboxItem] = []
    var saved: [SavedItem] = []
    var manifests: [ModelManifest] = []
    var selectedIndex = 0
    var installed = false
    var storageBytes: Int64 = 0
    var downloading = false
    var downloadProgress: Double = 0
    var activeItem: UUID?
    var error: String?
    var setupError: String?
    var metrics: [InferenceMetrics] = []
    var benchmarkRunning = false
    var benchmarkCompleted = 0
    var benchmarkResults: [BenchmarkResult] = []
    var actionBusy = false
    var maintenance = false
    var isBusy: Bool { activeItem != nil || downloading || benchmarkRunning || actionBusy || maintenance }
    var selected: ModelManifest? { manifests.indices.contains(selectedIndex) ? manifests[selectedIndex] : nil }
    private(set) var inbox: InboxStore?
    private(set) var saver: LocalSaveActionExecutor?
    private(set) var coordinator: ActionCoordinator?
    let calendar = CalendarActionExecutor()
    let reminders = ReminderActionExecutor()
    private var downloader: ModelDownloadService?
    private var manager: ModelManager?
    private var journal: ActionJournal?
    private var root: URL?
    private var operation: Task<Void, Never>?
    private var transfer: Task<Void, Never>?
    private var benchmarkTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "PrivateAction", category: "Lifecycle")

    init() {
        do {
            let root = try SharedContainer.privateRoot(); self.root = root
            guard let resource = Bundle.main.url(forResource: "ModelManifests", withExtension: "json") else { throw PrivateActionError.unavailable }
            manifests = try JSONDecoder().decode([ModelManifest].self, from: Data(contentsOf: resource))
            inbox = try SharedContainer.inbox()
            downloader = try ModelDownloadService(root: root.appendingPathComponent("Models"))
            saver = try LocalSaveActionExecutor(root: root.appendingPathComponent("Saved"))
            let journal = try ActionJournal(root: root.appendingPathComponent("ActionJournal")); self.journal = journal
            coordinator = ActionCoordinator(journal: journal)
            if let data = try? SecureFiles.read(root.appendingPathComponent("metrics.json"), limit: 512_000) {
                metrics = (try? JSONDecoder().decode([InferenceMetrics].self, from: data)) ?? []
            }
            Task { await refresh(recover: true) }
        } catch { setupError = "Storage could not be opened. Check the App Group and signing configuration, then unlock your iPhone and relaunch." }
    }
    func refresh(recover: Bool = false) async {
        do {
            if recover { try await inbox?.recoverAndExpire() }
            items = try await inbox?.list() ?? []
            saved = try saver?.list() ?? []
            if let selected, let downloader {
                installed = await downloader.installed(selected); storageBytes = await downloader.storageBytes(selected)
                if manager == nil {
                    manager = ModelManager(runner: QwenModelRunner(manifest: selected, directory: await downloader.directory(selected)), onMetrics: { [weak self] metric in await self?.record(metric) })
                }
            }
        } catch { report(error) }
    }
    func importText(_ text: String) async {
        do {
            let value = try InputValidator.text(text)
            _ = try await inbox?.importData(Data(value.utf8), kind: .text)
            await refresh()
        } catch { report(error) }
    }
    func importFile(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try SecureFiles.read(url, limit: SecurityPolicy.maxInputBytes)
            let kind: SourceKind
            let result: Data
            if data.starts(with: Data("%PDF-".utf8)) { kind = .pdf; result = data }
            else {
                let image = try OCRService.downsample(data)
                guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else { throw PrivateActionError.invalidInput }
                kind = .image; result = jpeg
            }
            _ = try await inbox?.importData(result, kind: kind); await refresh()
        } catch { report(error) }
    }
    func analyze(_ item: InboxItem) {
        guard !isBusy, let inbox, let manager else { return }
        guard installed else { error = PrivateActionError.missingModel.localizedDescription; return }
        activeItem = item.id
        operation = Task {
            defer { activeItem = nil; operation = nil }
            var working = item; working.status = .processing; working.failure = nil
            let attemptStart = Date()
            do {
                try await inbox.update(working); await refresh()
                let input = try await ContentProcessor().process(item, url: await inbox.payloadURL(item))
                try Task.checkCancellation()
                let result = try await manager.analyze(input)
                try Task.checkCancellation()
                try await inbox.finish(item, proposal: result.proposal)
                logger.info("Local analysis completed")
            } catch {
                working.status = .failed
                working.failure = Self.safeMessage(error)
                try? await inbox.update(working)
                var failed = InferenceMetrics(model: selected?.repo ?? "", revision: selected?.revision ?? "", quantization: selected?.bits ?? 4)
                failed.generationSeconds = Date().timeIntervalSince(attemptStart)
                failed.thermalAfter = ResourceLimiter.thermalLabel; record(failed)
                logger.notice("Local analysis stopped")
            }
            // Release weights and Metal caches between tasks; benchmark load time remains honest.
            await manager.unload(); await refresh()
        }
    }
    func cancelAnalysis() { operation?.cancel(); Task { await manager?.cancel() } }
    func resourcePressure() {
        cancelAnalysis(); benchmarkTask?.cancel()
        Task { await manager?.unload() }
    }
    func downloadModel() {
        guard !isBusy, let selected, let downloader else { return }
        downloading = true; downloadProgress = 0
        transfer = Task {
            defer { downloading = false; transfer = nil }
            do {
                try await downloader.install(selected) { [weak self] fraction in
                    Task { @MainActor in self?.downloadProgress = fraction }
                }
            } catch { if !(error is CancellationError) && (error as NSError).code != NSURLErrorCancelled { report(error) } }
            await refresh()
        }
    }
    func cancelDownload() { transfer?.cancel() }
    func switchModel(_ index: Int) async {
        guard !isBusy, manifests.indices.contains(index) else { return }
        maintenance = true; defer { maintenance = false }
        await manager?.unload(); manager = nil; selectedIndex = index; await refresh()
    }
    func deleteModel() async {
        guard !isBusy, let selected else { return }
        maintenance = true; defer { maintenance = false }
        await manager?.unload()
        do { try await downloader?.delete(selected); await refresh() } catch { report(error) }
    }
    func deleteItem(_ item: InboxItem) async {
        guard !isBusy else { return }
        do { try await inbox?.delete(item.id); await refresh() } catch { report(error) }
    }
    func toggleSaved(_ itemID: UUID, rowID: UUID) {
        guard !isBusy, let itemIndex = saved.firstIndex(where: { $0.id == itemID }),
              let rowIndex = saved[itemIndex].checklist.firstIndex(where: { $0.id == rowID }) else { return }
        var changed = saved[itemIndex]; changed.checklist[rowIndex].completed.toggle()
        do { try saver?.update(changed); saved[itemIndex] = changed } catch { report(error) }
    }
    func deleteAllData() async {
        guard !isBusy else { return }
        maintenance = true; defer { maintenance = false }
        await manager?.unload()
        do {
            try await inbox?.deleteAll(); try saver?.deleteAll(); try await journal?.deleteAll()
            metrics = []; benchmarkResults = []
            if let root { try SecureFiles.write(JSONEncoder().encode(metrics), to: root.appendingPathComponent("metrics.json")) }
            await refresh()
        } catch { report(error) }
    }
    func execute(_ review: ActionReview, proposal: ValidatedProposal) async throws {
        guard !isBusy, let coordinator, let saver else { throw PrivateActionError.busy }
        actionBusy = true; defer { actionBusy = false }
        let approved = try UserConfirmation.approve(review, proposal: proposal)
        let executor: any ActionExecutor
        switch review.type {
        case .createCalendarEvent: executor = calendar
        case .createReminder: executor = reminders
        case .saveChecklist, .saveInformation:
            guard saved.count < SecurityPolicy.maxSavedItems else { throw PrivateActionError.tooLarge }; executor = saver
        case .draftReply: throw PrivateActionError.invalidInput
        }
        try await coordinator.perform(approved, executor: executor); await refresh()
    }
    func runBenchmarks() {
        guard !isBusy, installed, let manager else { return }
        benchmarkRunning = true; benchmarkCompleted = 0; benchmarkResults = []
        benchmarkTask = Task {
            defer { benchmarkRunning = false; benchmarkTask = nil }
            for fixture in BenchmarkSuite.cases {
                if Task.isCancelled { break }
                do {
                    let result = try await manager.analyze(AnalysisInput(text: fixture.text))
                    let pass = fixture.accepts(result.proposal.value)
                    benchmarkResults.append(BenchmarkResult(name: fixture.name, passed: pass, note: pass ? "Matched expected constraints" : "Valid structure; semantic expectation failed"))
                } catch {
                    var failed = InferenceMetrics(model: selected?.repo ?? "", revision: selected?.revision ?? "", quantization: selected?.bits ?? 4)
                    failed.thermalAfter = ResourceLimiter.thermalLabel; record(failed)
                    benchmarkResults.append(BenchmarkResult(name: fixture.name, passed: false, note: Self.safeMessage(error)))
                }
                await manager.unload(); benchmarkCompleted += 1
                if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical { break }
            }
        }
    }
    func cancelBenchmarks() { benchmarkTask?.cancel(); Task { await manager?.cancel() } }
    private func record(_ value: InferenceMetrics) {
        metrics.append(value); metrics = Array(metrics.suffix(200))
        do { if let root { try SecureFiles.write(JSONEncoder().encode(metrics), to: root.appendingPathComponent("metrics.json")) } }
        catch { report(error) }
    }
    func report(_ error: Error) { self.error = Self.safeMessage(error) }
    static func safeMessage(_ error: Error) -> String {
        if error is CancellationError { return PrivateActionError.cancelled.localizedDescription }
        if let known = error as? PrivateActionError { return known.localizedDescription }
        return "The operation couldn’t finish. Nothing was automatically executed. Check storage, permissions, or the model download and try again."
    }
}
