import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import PrivateActionCore
import os

// The only model API is a local directory. No Hub repo ID or downloader is passed here.
actor QwenModelRunner: LocalLanguageModel {
    private let manifest: ModelManifest
    private let directory: URL
    private var container: ModelContainer?
    init(manifest: ModelManifest, directory: URL) { self.manifest = manifest; self.directory = directory }
    func load() async throws {
        if container != nil { return }
        try ResourceLimiter.check(minimumBytes: UInt64(Double(manifest.totalBytes) * 1.5) + 350_000_000)
        guard FileManager.default.fileExists(atPath: directory.path) else { throw PrivateActionError.missingModel }
        try ModelAssetVerifier.verifyDirectory(directory, manifest: manifest)
        try Task.checkCancellation()
        GPU.set(cacheLimit: 64 * 1024 * 1024)
        container = try await LLMModelFactory.shared.loadContainer(configuration: .init(directory: directory))
        try Task.checkCancellation()
    }
    func generate(_ input: AnalysisInput) async throws -> GenerationOutput {
        guard let container else { throw PrivateActionError.missingModel }
        try ResourceLimiter.check()
        let manifest = self.manifest
        return try await container.perform { context in
            let prompt = UserInput(messages: [
                ["role": "system", "content": PromptBuilder.system],
                ["role": "user", "content": PromptBuilder.user(input)]
            ], additionalContext: ["enable_thinking": false])
            let prepared = try await context.processor.prepare(input: prompt)
            let inputTokens = prepared.text.tokens.size
            guard inputTokens <= SecurityPolicy.maxInputTokens else { throw PrivateActionError.tooLarge }
            try ResourceLimiter.check(); try Task.checkCancellation()
            var metrics = InferenceMetrics(model: manifest.repo, revision: manifest.revision, quantization: manifest.bits)
            metrics.inputTokens = inputTokens; metrics.thermalBefore = ResourceLimiter.thermalLabel
            GPU.resetPeakMemory()
            let start = Date()
            var stopped: Error?
            // Token callback provides synchronous, bounded cancellation and exact token counts.
            let result = try MLXLMCommon.generate(input: prepared, parameters: GenerateParameters(
                maxTokens: SecurityPolicy.maxOutputTokens, maxKVSize: 4096, temperature: 0, prefillStepSize: 128
            ), context: context) { tokens in
                if metrics.firstTokenSeconds == nil { metrics.firstTokenSeconds = Date().timeIntervalSince(start) }
                do {
                    try Task.checkCancellation(); try ResourceLimiter.check()
                    if Date().timeIntervalSince(start) > SecurityPolicy.generationTimeout { throw PrivateActionError.timedOut }
                } catch { stopped = error; return .stop }
                return tokens.count >= SecurityPolicy.maxOutputTokens ? .stop : .more
            }
            if let stopped { throw stopped }
            try Task.checkCancellation()
            metrics.outputTokens = result.tokens.count
            metrics.generationSeconds = Date().timeIntervalSince(start)
            metrics.peakMLXBytes = GPU.peakMemory; metrics.thermalAfter = ResourceLimiter.thermalLabel
            return GenerationOutput(json: Data(result.output.utf8), metrics: metrics)
        }
    }
    func unload() async { container = nil; GPU.clearCache() }
}

enum ResourceLimiter {
    static var thermalLabel: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
    static func check(minimumBytes: UInt64 = 180_000_000) throws {
        let thermal = ProcessInfo.processInfo.thermalState
        guard thermal != .serious && thermal != .critical else { throw PrivateActionError.tooHot }
        #if os(iOS)
        guard os_proc_available_memory() >= minimumBytes else { throw PrivateActionError.lowMemory }
        #else
        throw PrivateActionError.unavailable // Inference is supported only on the target iPhone.
        #endif
    }
}
