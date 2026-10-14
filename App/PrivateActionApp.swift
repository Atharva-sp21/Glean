import SwiftUI
import UIKit
import PrivateActionCore

@main struct PrivateActionApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(environment).tint(AppStyle.mint).preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.refresh() } }
                    else if phase == .background { environment.resourcePressure() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in environment.resourcePressure() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in environment.resourcePressure() }
                .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                    if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical { environment.resourcePressure() }
                }
        }
    }
}

// Explicit Shortcuts input only; no clipboard polling or screen monitoring.
import AppIntents
import UniformTypeIdentifiers

@MainActor @Observable final class ShortcutInbox {
    static let shared = ShortcutInbox()
    var pendingID: UUID?
}

struct AnalyzeScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Analyze Screenshot in Glean"
    static let description = IntentDescription("Import a screenshot and open Glean to analyze it locally. Review suggested actions before saving.")
    static let openAppWhenRun: Bool = true
    @Parameter(title: "Screenshot")
    var screenshot: IntentFile

    @MainActor func perform() async throws -> some IntentResult {
        let data = screenshot.data
        try InputValidator.byteCount(data.count)
        let image = try OCRService.downsample(data)
        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else {
            throw PrivateActionError.invalidInput
        }
        let store = try SharedContainer.inbox()
        let item = try await store.importData(jpeg, kind: .image)
        ShortcutInbox.shared.pendingID = item.id
        return .result()
    }
}
