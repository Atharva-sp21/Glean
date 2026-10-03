import SwiftUI
import UIKit
import PrivateActionCore

struct AnalysisView: View {
    @Environment(AppEnvironment.self) private var app
    let id: UUID
    @State private var selectedAction: ProposedAction?
    @State private var checked: Set<String> = []
    private var item: InboxItem? { app.items.first { $0.id == id } }
    var body: some View {
        Group {
            if let item {
                if let raw = item.proposal, let proposal = try? OutputValidator.validate(raw) {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(raw.category.rawValue.capitalized, systemImage: "sparkle").font(.caption.weight(.semibold)).foregroundStyle(.teal)
                                Text(raw.title).font(.title2.bold())
                                ForEach(Array(raw.dates.enumerated()), id: \.offset) { _, date in
                                    Label(date.rawText, systemImage: "calendar")
                                    if date.iso8601 == nil { Text("Date or time is incomplete. Confirm it before adding.").font(.caption).foregroundStyle(.orange) }
                                }
                            }.padding(.vertical, 8)
                        }
                        Section("Summary") { Text(raw.summary).textSelection(.enabled) }
                        if !raw.locations.isEmpty { Section("Locations") { ForEach(raw.locations, id: \.self) { Text($0) } } }
                        if !raw.people.isEmpty { Section("People") { ForEach(raw.people, id: \.self) { Text($0) } } }
                        if !raw.checklist.isEmpty {
                            Section("Checklist") {
                                ForEach(raw.checklist) { row in
                                    Button { if checked.contains(row.id) { checked.remove(row.id) } else { checked.insert(row.id) } } label: {
                                        Label(row.text, systemImage: checked.contains(row.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(checked.contains(row.id) ? .secondary : .primary)
                                    }.accessibilityAddTraits(checked.contains(row.id) ? .isSelected : [])
                                }
                            }
                        }
                        Section {
                            ForEach(raw.proposedActions) { action in
                                Button { selectedAction = action } label: {
                                    HStack {
                                        Image(systemName: action.type.icon).frame(width: 26)
                                        VStack(alignment: .leading, spacing: 4) { Text(action.type.label).font(.headline); Text(action.explanation).font(.caption).foregroundStyle(.secondary) }
                                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                                    }.padding(.vertical, 5)
                                }.disabled(app.isBusy)
                            }
                        } header: { Text("Suggested actions") } footer: { Text("AI suggestions can be wrong. Review every detail. Nothing happens until you confirm.") }
                        Label("Analyzed locally · original source removed", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }.sheet(item: $selectedAction) { action in ActionReviewView(itemID: id, proposal: proposal, action: action) }
                } else {
                    VStack(spacing: 22) {
                        Image(systemName: item.status == .processing ? "sparkles" : "doc.text.magnifyingglass").font(.system(size: 48)).foregroundStyle(.teal)
                        Text(item.status == .processing ? "Understanding on your iPhone" : "Ready to understand").font(.title2.bold())
                        Text(item.failure ?? "Extract useful information privately, then choose what to do with it.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                        if item.status == .processing {
                            ProgressView(); Button("Cancel Analysis", role: .cancel) { app.cancelAnalysis() }
                        } else {
                            Button("Analyze Locally", systemImage: "sparkles") { app.analyze(item) }.buttonStyle(.borderedProminent).disabled(app.isBusy || !app.installed)
                            if !app.installed { Text("Install the local AI model in Settings first.").font(.footnote) }
                        }
                    }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { ContentUnavailableView("Item removed", systemImage: "tray") }
        }.navigationTitle("Analysis").navigationBarTitleDisplayMode(.inline)
    }
}

struct ActionReviewView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss
    let itemID: UUID
    let proposal: ValidatedProposal
    let action: ProposedAction
    @State private var title: String
    @State private var bodyText: String
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)
    @State private var dateConfirmed = false
    @State private var hasDueDate = false
    @State private var destinations: [(id: String, title: String)] = []
    @State private var destination = ""
    @State private var busy = false
    @State private var error: String?
    @State private var success = false
    @State private var showShare = false
    @State private var confirmShare = false
    @State private var copied = false

    init(itemID: UUID, proposal: ValidatedProposal, action: ProposedAction) {
        self.itemID = itemID; self.proposal = proposal; self.action = action
        _title = State(initialValue: action.title)
        let value = proposal.value
        _bodyText = State(initialValue: action.type == .draftReply ? "Thanks for the update about \(value.title)." : action.type == .saveChecklist ? value.checklist.map { "☐ " + $0.text }.joined(separator: "\n") : value.summary)
        if let iso = value.dates.first?.iso8601, let date = try? OutputValidator.parseDate(iso) {
            _start = State(initialValue: date); _end = State(initialValue: date.addingTimeInterval(3600))
        }
    }
    private var calendarAction: Bool { action.type == .createCalendarEvent }
    private var reminderAction: Bool { action.type == .createReminder }
    private var ready: Bool {
        !busy && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!(calendarAction || reminderAction) || !destination.isEmpty) &&
        (!(calendarAction || hasDueDate) || dateConfirmed) && (!calendarAction || end > start)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Review before confirming") {
                    TextField("Title", text: $title)
                    TextEditor(text: $bodyText).frame(minHeight: 100)
                }
                if calendarAction || reminderAction {
                    Section("Extracted date") {
                        ForEach(Array(proposal.value.dates.enumerated()), id: \.offset) { _, date in Text(date.rawText) }
                        Text("Choose the intended year, date and time below. Times use \(TimeZone.current.identifier).").font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Date and time") {
                        if reminderAction { Toggle("Set a due date", isOn: $hasDueDate) }
                        if calendarAction || hasDueDate {
                            DatePicker(calendarAction ? "Starts" : "Due", selection: $start)
                            if calendarAction { DatePicker("Ends", selection: $end) }
                            Toggle("I checked the date and time", isOn: $dateConfirmed)
                        }
                    }
                    Section(calendarAction ? "Calendar" : "Reminder list") {
                        if destinations.isEmpty {
                            Button("Choose \(calendarAction ? "Calendar" : "Reminder List")") { requestDestinations() }.disabled(busy)
                        } else {
                            Picker("Destination", selection: $destination) {
                                Text("Choose…").tag("")
                                ForEach(destinations, id: \.id) { row in Text(row.title).tag(row.id) }
                            }
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if action.type == .draftReply {
                    Section {
                        Button(copied ? "Copied" : "Copy Draft", systemImage: "doc.on.doc") {
                            do {
                                try OutputValidator.field(bodyText, max: 8000)
                                UIPasteboard.general.setItems([["public.utf8-plain-text": bodyText]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                                copied = true
                            } catch { self.error = AppEnvironment.safeMessage(error) }
                        }
                        Button("Share Draft…", systemImage: "square.and.arrow.up") { confirmShare = true }
                        Text("Edit this draft before using it. Copy is local to this device and expires after two minutes. Sharing opens the iOS share sheet; no message is sent automatically.").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Button { commit() } label: { HStack { Spacer(); if busy { ProgressView() } else { Text(calendarAction || reminderAction ? "Add" : "Save on This iPhone").bold() }; Spacer() } }.disabled(!ready)
                        Text(calendarAction || reminderAction ? "Your selected Calendar or Reminders account may sync through its own provider after you approve." : "This saves a local copy of the reviewed content.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }.navigationTitle(action.type == .draftReply ? "Review Draft" : action.type.label).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
                .interactiveDismissDisabled(busy)
                .onChange(of: start) { _, _ in dateConfirmed = false }
                .onChange(of: end) { _, _ in dateConfirmed = false }
                .alert("Added successfully", isPresented: $success) { Button("Done") { dismiss() } } message: { Text("Your approved action is complete.") }
                .confirmationDialog("Share this reviewed draft with another app?", isPresented: $confirmShare, titleVisibility: .visible) {
                    Button("Continue to Share Sheet") {
                        do { try OutputValidator.field(bodyText, max: 8000); showShare = true }
                        catch { self.error = AppEnvironment.safeMessage(error) }
                    }
                }
                .sheet(isPresented: $showShare) { ShareDraftSheet(text: bodyText) }
        }
    }
    private func requestDestinations() {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                if calendarAction { try await app.calendar.prepare(); destinations = app.calendar.calendars.map { ($0.calendarIdentifier, $0.title) } }
                else { try await app.reminders.prepare(); destinations = app.reminders.calendars.map { ($0.calendarIdentifier, $0.title) } }
                if destinations.isEmpty { error = "No writable destination is available. Add an account or list in Calendar or Reminders." }
            } catch { self.error = AppEnvironment.safeMessage(error) }
        }
    }
    private func commit() {
        busy = true; error = nil
        var review = ActionReview(itemID: itemID, type: action.type, title: title, body: bodyText)
        review.destinationID = destination; review.dateConfirmed = dateConfirmed
        if calendarAction || hasDueDate { review.start = start }
        if calendarAction { review.end = end }
        Task {
            defer { busy = false }
            do { try await app.execute(review, proposal: proposal); success = true }
            catch { self.error = AppEnvironment.safeMessage(error) }
        }
    }
}
struct ShareDraftSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [text], applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
