import SwiftUI
import PrivateActionCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var confirmData = false
    @State private var confirmModel = false
    var body: some View {
        Form {
            Section {
                Label("Private by design", systemImage: "lock.shield.fill").font(.headline).foregroundStyle(AppStyle.mint)
                Text("Glean analyzes content on your iPhone. Download a local model once, then analyze without an internet connection.")
            }
            Section("Local AI model") {
                if let model = app.selected {
                    LabeledContent("Model", value: model.name)
                    LabeledContent("Quantization", value: "\(model.bits)-bit")
                    LabeledContent("Download size", value: ByteCountFormatter.string(fromByteCount: model.totalBytes, countStyle: .file))
                    LabeledContent("Local model storage", value: ByteCountFormatter.string(fromByteCount: app.storageBytes, countStyle: .file))
                    LabeledContent("Status", value: app.installed ? "Downloaded" : "Not installed")
                }
                if app.downloading {
                    ProgressView(value: app.downloadProgress) { Text("Downloading model from the internet") } currentValueLabel: { Text(app.downloadProgress, format: .percent.precision(.fractionLength(0))) }
                    Button("Cancel Download", role: .cancel) { app.cancelDownload() }
                    Text("Retry keeps completed, verified files. An interrupted weight file downloads again.").font(.caption).foregroundStyle(.secondary)
                } else if !app.installed {
                    Button("Download Local AI Model", systemImage: "arrow.down.circle.fill") { app.downloadModel() }.disabled(app.isBusy)
                } else {
                    Label("Local AI ready", systemImage: "checkmark.circle.fill").foregroundStyle(AppStyle.mint)
                    Text("Model integrity is verified before every load.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Share to Glean") {
                NavigationLink("How sharing works") { ShareGuideView() }
                Text("Share from another app, then open Glean for automatic analysis and action review.")
            }
            Section("Optional: Back Tap shortcut") {
                Text("In Shortcuts, create Glean Screenshot with Take Screenshot followed by Analyze Screenshot in Glean. Pass the screenshot into the Glean action.")
                Text("Then choose it in iPhone Settings → Accessibility → Touch → Back Tap.")
                Text("Glean opens and analyzes automatically. Keep it visible while processing, then review any calendar or reminder action before saving.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                LabeledContent("Inference", value: "On device")
                LabeledContent("Cloud AI", value: "Disabled")
                LabeledContent("Webpage fetching", value: "Disabled")
                Text("No analytics. No content in logs. Shared originals are removed after successful analysis and expire after 24 hours when the app next runs. Saved results stay until you delete them.").font(.footnote).foregroundStyle(.secondary)
                Text("Calendar and Reminders may sync approved content through the account you choose. iOS controls screenshots, backups and other system behavior.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Storage controls") {
                Button("Delete All Local Data", role: .destructive) { confirmData = true }.disabled(app.isBusy)
                Button("Delete Selected Model", role: .destructive) { confirmModel = true }.disabled(app.isBusy)
            }
            Section { NavigationLink("Developer") { DeveloperView() } }
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Settings")
            .confirmationDialog("Delete all inbox items, saved content and local benchmark records?", isPresented: $confirmData, titleVisibility: .visible) {
                Button("Delete Local Data", role: .destructive) { Task { await app.deleteAllData() } }
            } message: { Text("Downloaded models and events or reminders already added to iOS are kept.") }
            .confirmationDialog("Delete the selected downloaded model?", isPresented: $confirmModel, titleVisibility: .visible) {
                Button("Delete Model", role: .destructive) { Task { await app.deleteModel() } }
            }
    }
}
struct DeveloperView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var pendingModel: Int?
    var body: some View {
        Form {
            Section("Model") {
                ForEach(Array(app.manifests.enumerated()), id: \.element.id) { index, model in
                    Button { pendingModel = index } label: {
                        HStack {
                            VStack(alignment: .leading) { Text("\(model.name) · \(model.bits)-bit"); Text(model.experimental ? "Experimental · larger memory requirement" : "Default · iPhone 15 target").font(.caption).foregroundStyle(.secondary) }
                            Spacer(); if app.selectedIndex == index { Image(systemName: "checkmark") }
                        }
                    }.disabled(app.isBusy)
                }
                Text("Selection does not download anything. Experimental models are opt-in for this session; relaunch returns to 1.7B 4-bit. Physical-device performance is unmeasured.").font(.footnote).foregroundStyle(.secondary)
            }
            Section { NavigationLink("Benchmark") { BenchmarkView() } }
            Section("Generation policy") {
                LabeledContent("Thinking", value: "Disabled")
                LabeledContent("Input limit", value: "3,072 tokens")
                LabeledContent("Output limit", value: "512 tokens")
                LabeledContent("Generation deadline", value: "45 seconds / attempt")
                Text("Pinned MLX 2.29.3 uses strict JSON validation and one bounded retry. Grammar-constrained decoding is not implemented in this dependency version.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Developer")
            .confirmationDialog("Use this model for this session?", isPresented: Binding(get: { pendingModel != nil }, set: { if !$0 { pendingModel = nil } }), titleVisibility: .visible) {
                Button("Select Model") { if let index = pendingModel { Task { await app.switchModel(index) } }; pendingModel = nil }
            } message: { Text("Larger models may exceed iPhone 15 memory. They are never loaded or downloaded automatically.") }
    }
}
struct BenchmarkView: View {
    @Environment(AppEnvironment.self) private var app
    var body: some View {
        List {
            Section {
                Text("20 synthetic cases. No user content is saved in measurements. This screen never executes proposed actions.")
                if app.benchmarkRunning {
                    ProgressView(value: Double(app.benchmarkCompleted), total: 20)
                    Button("Stop Benchmark", role: .cancel) { app.cancelBenchmarks() }
                } else { Button("Run Synthetic Suite", systemImage: "speedometer") { app.runBenchmarks() }.disabled(app.isBusy || !app.installed) }
            }
            if !app.benchmarkResults.isEmpty {
                Section("Semantic checks") {
                    ForEach(app.benchmarkResults) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(row.name, systemImage: row.passed ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(row.passed ? .teal : .orange)
                            Text(row.note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Measured local runs") {
                if app.metrics.isEmpty { Text("No measurements yet. Run on the physical iPhone 15 to collect results.").foregroundStyle(.secondary) }
                ForEach(app.metrics.reversed()) { metric in
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(metric.model.components(separatedBy: "/").last ?? metric.model) · \(metric.quantization)-bit").font(.caption.bold())
                        Text(metric.success ? "Validated output" : "Failed / cancelled").foregroundStyle(metric.success ? .teal : .orange)
                        if metric.success {
                            Text("Load \(metric.loadSeconds, specifier: "%.2f")s · generation \(metric.generationSeconds, specifier: "%.2f")s")
                            Text("Input \(metric.inputTokens ?? 0) · output \(metric.outputTokens ?? 0) tokens")
                            if let first = metric.firstTokenSeconds { Text("First token \(first, specifier: "%.2f")s") }
                            if let speed = metric.tokensPerSecond { Text("\(speed, specifier: "%.1f") output tokens/s (including prefill)") }
                            if let memory = metric.peakMLXBytes { Text("MLX peak \(ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory))") }
                        } else {
                            if let code = metric.failureCode { Text("Diagnostic: \(code)").textSelection(.enabled) }
                            Text("Input \(metric.inputTokens ?? 0) · output \(metric.outputTokens ?? 0) tokens")
                        }
                        Text("Thermal: \(metric.thermalBefore) → \(metric.thermalAfter)")
                    }.font(.caption)
                }
            }
        }.navigationTitle("Benchmark")
    }
}
