import SwiftUI
import UniformTypeIdentifiers
import PrivateActionCore

struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    var body: some View {
        @Bindable var app = app
        Group {
            if let problem = app.setupError { ContentUnavailableView("Setup needed", systemImage: "lock.trianglebadge.exclamationmark", description: Text(problem)) }
            else {
                TabView {
                    NavigationStack { InboxView() }.tabItem { Label("Inbox", systemImage: "tray") }
                    NavigationStack { SavedView() }.tabItem { Label("Saved", systemImage: "checkmark.square") }
                    NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
        }.alert("Glean", isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })) { Button("OK") { app.error = nil } } message: { Text(app.error ?? "") }
    }
}
struct InboxView: View {
    @Environment(AppEnvironment.self) private var app
    @State private var showText = false
    @State private var showFiles = false
    @State private var deleteTarget: InboxItem?
    var body: some View {
        List {
            Section {
                VStack(spacing: 22) {
                    Label(app.installed ? "ON-DEVICE INTELLIGENCE" : "YOUR PRIVATE SPACE", systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(AppStyle.mint)
                    Text("Make room for\nwhat matters.")
                        .font(.system(size: 38, weight: .semibold, design: .rounded)).tracking(-1.5)
                        .multilineTextAlignment(.center).foregroundStyle(.white)
                        .minimumScaleFactor(0.75)
                    Image("GleanLogo").resizable().scaledToFit().frame(width: 180, height: 180).clipShape(RoundedRectangle(cornerRadius: 36)).accessibilityLabel("Glean logo")
                    Text(app.installed ? "Turn a little context into a clear next step." : "Install your local model in Settings to begin.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                    Button { showText = true } label: {
                        Label("Add your context", systemImage: "plus").frame(maxWidth: .infinity)
                    }.buttonStyle(EmeraldButtonStyle())
                    Button { showFiles = true } label: {
                        Label("Import a photo or PDF", systemImage: "doc.badge.plus")
                            .font(.subheadline).foregroundStyle(AppStyle.mint)
                    }.buttonStyle(.plain)
                }.padding(.vertical, 18).frame(maxWidth: .infinity)
            }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            if app.items.isEmpty {
                Text("Or share text, screenshots and documents directly from another app.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            } else {
                Section("Received on this iPhone") {
                    ForEach(app.items) { item in
                        NavigationLink { AnalysisView(id: item.id) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(item.kind)).font(.title2).foregroundStyle(AppStyle.mint).frame(width: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.proposal?.title ?? "Shared \(item.kind.rawValue)").font(.headline).lineLimit(2)
                                    Text(item.receivedAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.status == .processing { ProgressView() }
                                else { Text(item.status.rawValue.capitalized).font(.caption.weight(.medium)).foregroundStyle(item.status == .failed ? .orange : .secondary) }
                            }.padding(.vertical, 5)
                        }.swipeActions { Button("Delete", role: .destructive) { deleteTarget = item }.disabled(app.isBusy) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Glean").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("Add Text", systemImage: "text.badge.plus") { showText = true }; Button("Import Image or PDF", systemImage: "doc.badge.plus") { showFiles = true } } label: { Image(systemName: "plus.circle.fill") } } }
        .refreshable { await app.refresh() }
        .sheet(isPresented: $showText) { AddTextView() }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.image, .pdf]) { result in
            switch result { case .success(let url): Task { await app.importFile(url) }; case .failure(let error): app.report(error) }
        }
        .confirmationDialog("Delete this item and its local content?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button("Delete Item", role: .destructive) { if let item = deleteTarget { Task { await app.deleteItem(item) } }; deleteTarget = nil }
        }
    }
    private func icon(_ kind: SourceKind) -> String { switch kind { case .image: "photo"; case .pdf: "doc.richtext"; case .text: "text.alignleft"; case .url: "link" } }
}
struct AddTextView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Text("A thought. A plan.\nA little context.").font(.system(size: 32, weight: .semibold)).tracking(-1)
                Text("Paste the details. Choose what happens next.").foregroundStyle(.secondary)
                TextEditor(text: $text).font(.title3).scrollContentBackground(.hidden)
                    .padding(16).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.12)))
                    .accessibilityLabel("Content to analyze")
                Text("\(text.count) / 12,000 characters · stays on this iPhone")
                    .font(.caption).foregroundStyle(text.count > SecurityPolicy.maxTextCharacters ? .orange : .secondary)
                Button { Task { await app.importText(text); dismiss() } } label: {
                    Text("Add to Inbox").frame(maxWidth: .infinity)
                }.buttonStyle(EmeraldButtonStyle())
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > SecurityPolicy.maxTextCharacters)
            }.padding(24).background(AppBackdrop())
            .navigationTitle("Add Text").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { Task { await app.importText(text); dismiss() } }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > SecurityPolicy.maxTextCharacters) }
                }
        }
    }
}
struct SavedView: View {
    @Environment(AppEnvironment.self) private var app
    var body: some View {
        List {
            if app.saved.isEmpty { ContentUnavailableView("Nothing saved yet", systemImage: "checkmark.square", description: Text("Checklists and information you choose to save appear here.")) }
            ForEach(app.saved) { item in
                NavigationLink { SavedDetailView(id: item.id) } label: { Label(item.title, systemImage: item.checklist.isEmpty ? "doc.text" : "checklist") }
            }
        }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Saved")
    }
}

struct SavedDetailView: View {
    @Environment(AppEnvironment.self) private var app
    let id: UUID
    var body: some View {
        if let item = app.saved.first(where: { $0.id == id }) {
            List {
                Section { Text(item.title).font(.title2.bold()) }
                if item.checklist.isEmpty { Section { Text(item.body).textSelection(.enabled) } }
                else {
                    Section("Checklist") {
                        ForEach(item.checklist) { row in
                            Button { app.toggleSaved(id, rowID: row.id) } label: {
                                Label(row.text, systemImage: row.completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(row.completed ? .secondary : .primary)
                            }.disabled(app.isBusy)
                        }
                    }
                }
                Text(item.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
            }.scrollContentBackground(.hidden).background(AppBackdrop()).navigationTitle("Saved").navigationBarTitleDisplayMode(.inline)
        } else { ContentUnavailableView("Item removed", systemImage: "tray") }
    }
}

// Shared visual language: luminous emerald on warm black, with native controls.
enum AppStyle {
    static let mint = Color(red: 0.08, green: 0.94, blue: 0.55)
}
struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [AppStyle.mint.opacity(0.13), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
        }.ignoresSafeArea()
    }
}
struct EmeraldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.black)
            .padding(.vertical, 18).padding(.horizontal, 24)
            .background(LinearGradient(colors: [AppStyle.mint, Color(red: 0.04, green: 0.67, blue: 0.39)], startPoint: .leading, endPoint: .trailing), in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.35)
    }
}
struct EmeraldOrb: View {
    var body: some View {
        ZStack {
            Circle().fill(AppStyle.mint.opacity(0.14)).blur(radius: 24).frame(width: 150, height: 150)
            ForEach(0..<4) { index in
                Ellipse().stroke(LinearGradient(colors: [.clear, AppStyle.mint.opacity(0.4), AppStyle.mint, .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: index == 0 ? 3 : 1.5)
                    .frame(width: 132 + CGFloat(index * 9), height: 154)
                    .rotationEffect(.degrees(Double(index * 43)))
                    .shadow(color: AppStyle.mint.opacity(0.8), radius: 8)
            }
        }.accessibilityHidden(true)
    }
}
