import XCTest
@testable import PrivateActionCore

private actor TestRunner: LocalLanguageModel {
    var generations = 0
    var started = false
    var unloaded = false
    let loadError: PrivateActionError?
    let slow: Bool
    init(loadError: PrivateActionError? = nil, slow: Bool = false) { self.loadError = loadError; self.slow = slow }
    func load() async throws { if let loadError { throw loadError } }
    func generate(_ input: AnalysisInput) async throws -> GenerationOutput {
        generations += 1; started = true
        if slow { try await Task.sleep(for: .seconds(30)) }
        return GenerationOutput(json: Data("bad json".utf8), metrics: InferenceMetrics())
    }
    func unload() async { unloaded = true }
}
final class LifecycleTests: XCTestCase {
    func testMissingModel() async throws {
        let manager = ModelManager(runner: TestRunner(loadError: .missingModel))
        do { _ = try await manager.analyze(AnalysisInput(text: "test")); XCTFail("Should fail") }
        catch { XCTAssertEqual(error as? PrivateActionError, .missingModel) }
    }
    func testLowMemory() async throws {
        let manager = ModelManager(runner: TestRunner(loadError: .lowMemory))
        do { _ = try await manager.analyze(AnalysisInput(text: "test")); XCTFail("Should fail") }
        catch { XCTAssertEqual(error as? PrivateActionError, .lowMemory) }
    }
    func testOneRetry() async throws {
        let runner = TestRunner(); let manager = ModelManager(runner: runner)
        do { _ = try await manager.analyze(AnalysisInput(text: "test")); XCTFail("Should fail") } catch {}
        let count = await runner.generations; XCTAssertEqual(count, 2)
    }
    func testCancelAndUnload() async throws {
        let runner = TestRunner(slow: true); let manager = ModelManager(runner: runner)
        let job = Task { try await manager.analyze(AnalysisInput(text: "test")) }
        while !(await runner.started) { await Task.yield() }
        await manager.unload()
        do { _ = try await job.value; XCTFail("Should cancel") } catch { XCTAssertTrue(error is CancellationError) }
        let unloaded = await runner.unloaded; XCTAssertTrue(unloaded)
    }
    func testNoNetworkDependencyInCorePipeline() async throws {
        // A model stub has no downloader. This exercises separation, not physical offline inference.
        let manager = ModelManager(runner: TestRunner())
        do { _ = try await manager.analyze(AnalysisInput(text: "test")); XCTFail("Invalid output") }
        catch { XCTAssertEqual(error as? PrivateActionError, .invalidOutput) }
    }
}
@MainActor final class AuthorizationTests: XCTestCase {
    private final class Denied: ActionExecutor {
        var writes = 0
        func prepare() async throws { throw PrivateActionError.permissionDenied }
        func execute(_ action: ApprovedAction) async throws { writes += 1 }
    }
    func testDeniedCalendarAndReminderNeverReachWrite() async throws {
        let json = #"{"category":"event","title":"Dentist","summary":"Appointment","dates":[],"locations":[],"people":[],"checklist":[],"proposedActions":[{"type":"createCalendarEvent","title":"Dentist","explanation":"review"},{"type":"createReminder","title":"Dentist","explanation":"review"}]}"#
        let proposal = try OutputValidator.decode(Data(json.utf8))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = ActionCoordinator(journal: try ActionJournal(root: root))
        for type in [ProposedActionType.createCalendarEvent, .createReminder] {
            var review = ActionReview(itemID: UUID(), type: type, title: "Dentist", body: "")
            review.start = Date(); review.end = Date().addingTimeInterval(3600); review.dateConfirmed = true; review.destinationID = "test"
            let executor = Denied()
            do { try await coordinator.perform(UserConfirmation.approve(review, proposal: proposal), executor: executor); XCTFail("Denied") }
            catch { XCTAssertEqual(error as? PrivateActionError, .permissionDenied) }
            XCTAssertEqual(executor.writes, 0)
        }
    }
}

private actor CompactRetryRunner: LocalLanguageModel {
    var attempts: [Int] = []
    func load() async throws {}
    func unload() async {}
    func generate(_ input: AnalysisInput) async throws -> GenerationOutput {
        XCTFail("Manager must pass retry context")
        return GenerationOutput(json: Data(), metrics: InferenceMetrics())
    }
    func generate(_ input: AnalysisInput, attempt: Int) async throws -> GenerationOutput {
        attempts.append(attempt)
        let text = attempt == 0 ? "{\"category\":\"generic\"" : #"{"category":"generic","title":"Resume","summary":"Software engineering experience and education.","dates":[],"locations":[],"people":[],"checklist":[],"proposedActions":[{"type":"saveInformation","title":"Save overview","explanation":"Keep for reference."}]}"#
        return GenerationOutput(json: Data(text.utf8), metrics: InferenceMetrics())
    }
}
final class CompactRetryTests: XCTestCase {
    func testTruncatedResponseRetriesWithContextAndValidates() async throws {
        let runner = CompactRetryRunner()
        let result = try await ModelManager(runner: runner).analyze(AnalysisInput(text: "Resume: software engineering experience and education."))
        let attempts = await runner.attempts
        XCTAssertEqual(attempts, [0, 1])
        XCTAssertEqual(result.proposal.value.proposedActions.map(\.type), [.saveInformation])
        XCTAssertTrue(result.metrics.success)
    }
}
