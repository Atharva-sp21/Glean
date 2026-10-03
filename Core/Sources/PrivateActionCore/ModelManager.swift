import Foundation

public struct InferenceMetrics: Codable, Sendable, Identifiable {
    public let id: UUID
    public var model: String
    public var revision: String
    public var quantization: Int
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var loadSeconds: Double
    public var firstTokenSeconds: Double?
    public var generationSeconds: Double
    public var peakMLXBytes: Int?
    public var thermalBefore: String
    public var thermalAfter: String
    public var success: Bool
    public var tokensPerSecond: Double? {
        guard let outputTokens, generationSeconds > 0 else { return nil }; return Double(outputTokens) / generationSeconds
    }
    public init(model: String = "", revision: String = "", quantization: Int = 4) {
        id = UUID(); self.model = model; self.revision = revision; self.quantization = quantization; loadSeconds = 0; generationSeconds = 0
        thermalBefore = "unknown"; thermalAfter = "unknown"; success = false
    }
}
public struct GenerationOutput: Sendable {
    public let json: Data
    public var metrics: InferenceMetrics
    public init(json: Data, metrics: InferenceMetrics) { self.json = json; self.metrics = metrics }
}
public protocol LocalLanguageModel: Sendable {
    func load() async throws
    func generate(_ input: AnalysisInput) async throws -> GenerationOutput
    func unload() async
}
public struct AnalysisResult: Sendable {
    public let proposal: ValidatedProposal
    public let metrics: InferenceMetrics
}
public actor ModelManager {
    private let runner: any LocalLanguageModel
    private let onMetrics: @Sendable (InferenceMetrics) async -> Void
    private var job: Task<AnalysisResult, Error>?
    private var unloading = false
    public init(runner: any LocalLanguageModel, onMetrics: @escaping @Sendable (InferenceMetrics) async -> Void = { _ in }) { self.runner = runner; self.onMetrics = onMetrics }
    public func analyze(_ input: AnalysisInput) async throws -> AnalysisResult {
        guard job == nil, !unloading else { throw PrivateActionError.busy }
        let runner = self.runner
        let onMetrics = self.onMetrics
        let task = Task<AnalysisResult, Error> {
            let start = Date()
            try Task.checkCancellation(); try await runner.load(); try Task.checkCancellation()
            let loadTime = Date().timeIntervalSince(start)
            // One bounded retry. Invalid model text is never fed back into the prompt.
            for attempt in 0..<2 {
                var output = try await runner.generate(input)
                try Task.checkCancellation()
                do {
                    let proposal = try OutputValidator.decode(output.json)
                    output.metrics.loadSeconds = attempt == 0 ? loadTime : 0; output.metrics.success = true
                    await onMetrics(output.metrics)
                    return AnalysisResult(proposal: proposal, metrics: output.metrics)
                } catch {
                    output.metrics.loadSeconds = attempt == 0 ? loadTime : 0
                    output.metrics.success = false
                    await onMetrics(output.metrics)
                    if attempt == 1 { throw error }
                }
            }
            throw PrivateActionError.invalidOutput
        }
        job = task
        defer { job = nil }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
    public func cancel() { job?.cancel() }
    public func unload() async {
        guard !unloading else { return }
        unloading = true; job?.cancel()
        if let job { _ = await job.result }
        await runner.unload(); unloading = false
    }
}
