import Foundation
import EventKit
import PrivateActionCore

@MainActor final class CalendarActionExecutor: ActionExecutor {
    let store = EKEventStore()
    func prepare() async throws {
        let granted: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestFullAccessToEvents { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
        guard granted else { throw PrivateActionError.permissionDenied }
    }
    var calendars: [EKCalendar] { store.calendars(for: .event).filter(\.allowsContentModifications) }
    func execute(_ action: ApprovedAction) async throws {
        let review = action.review
        guard review.type == .createCalendarEvent, let start = review.start, let end = review.end,
              let calendar = calendars.first(where: { $0.calendarIdentifier == review.destinationID }) else { throw PrivateActionError.invalidInput }
        let event = EKEvent(eventStore: store)
        event.title = review.title; event.notes = review.body; event.startDate = start; event.endDate = end
        event.calendar = calendar
        try store.save(event, span: .thisEvent, commit: true)
    }
}
@MainActor final class ReminderActionExecutor: ActionExecutor {
    let store = EKEventStore()
    func prepare() async throws {
        let granted: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestFullAccessToReminders { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
        guard granted else { throw PrivateActionError.permissionDenied }
    }
    var calendars: [EKCalendar] { store.calendars(for: .reminder).filter(\.allowsContentModifications) }
    func execute(_ action: ApprovedAction) async throws {
        let review = action.review
        guard review.type == .createReminder,
              let calendar = calendars.first(where: { $0.calendarIdentifier == review.destinationID }) else { throw PrivateActionError.invalidInput }
        let reminder = EKReminder(eventStore: store); reminder.calendar = calendar
        reminder.title = review.title; reminder.notes = review.body
        if let date = review.start {
            var components = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
            components.timeZone = TimeZone.current; reminder.dueDateComponents = components
        }
        try store.save(reminder, commit: true)
    }
}
@MainActor final class LocalSaveActionExecutor: ActionExecutor {
    let root: URL
    init(root: URL) throws { self.root = root; try SecureFiles.directory(root) }
    func prepare() async throws {}
    func execute(_ action: ApprovedAction) async throws {
        guard [.saveChecklist, .saveInformation].contains(action.review.type) else { throw PrivateActionError.invalidInput }
        let checklist = action.review.type == .saveChecklist ? action.review.body.split(separator: "\n").map { line in
            SavedChecklistItem(text: line.hasPrefix("☐ ") ? String(line.dropFirst(2)) : String(line))
        } : []
        let item = SavedItem(id: UUID(), title: action.review.title, body: action.review.body, checklist: checklist)
        try SecureFiles.write(JSONEncoder().encode(item), to: root.appendingPathComponent(item.id.uuidString + ".json"))
    }
    func update(_ item: SavedItem) throws {
        let file = root.appendingPathComponent(item.id.uuidString + ".json")
        guard FileManager.default.fileExists(atPath: file.path) else { throw PrivateActionError.invalidInput }
        try SecureFiles.write(JSONEncoder().encode(item), to: file)
    }
    func list() throws -> [SavedItem] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).map {
            try JSONDecoder().decode(SavedItem.self, from: SecureFiles.read($0, limit: 64_000))
        }.sorted { $0.createdAt > $1.createdAt }
    }
    func deleteAll() throws {
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) { try FileManager.default.removeItem(at: url) }
    }
}
