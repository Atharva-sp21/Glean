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
        }.alert("Private Action", isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })) { Button("OK") { app.error = nil } } message: { Text(app.error ?? "") }
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
                HStack(spacing: 12) {
                    Image(systemName: app.installed ? "lock.shield.fill" : "arrow.down.circle").font(.title2).foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.installed ? "Local AI ready" : "Your private action inbox").font(.headline)
                        Text(app.installed ? "Analysis happens on this iPhone." : "Download a model in Settings to begin.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            if app.items.isEmpty {
                ContentUnavailableView {
                    Label("Share it. Make it useful.", systemImage: "square.and.arrow.up")
                } description: {
                    Text("Send a screenshot, PDF, website address, or text to Private Action from the Share Sheet.")
                } actions: {
                    Button("Add Text", systemImage: "text.badge.plus") { showText = true }.buttonStyle(.borderedProminent)
                }.listRowBackground(Color.clear)
            } else {
                Section("Received on this iPhone") {
                    ForEach(app.items) { item in
                        NavigationLink { AnalysisView(id: item.id) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: icon(item.kind)).font(.title2).foregroundStyle(.teal).frame(width: 36)
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
        .navigationTitle("Private Action")
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
            Form {
                Section("Content to understand") { TextEditor(text: $text).frame(minHeight: 220) }
                Text("No prompt needed. Paste the information you want to turn into actions. Up to 12,000 characters.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Add Text").navigationBarTitleDisplayMode(.inline)
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
        }.navigationTitle("Saved")
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
            }.navigationTitle("Saved").navigationBarTitleDisplayMode(.inline)
        } else { ContentUnavailableView("Item removed", systemImage: "tray") }
    }
}
