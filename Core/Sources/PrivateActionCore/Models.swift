import Foundation

public enum ContentCategory: String, Codable, Sendable { case event, task, travel, order, contact, study, generic }
public enum ProposedActionType: String, Codable, CaseIterable, Sendable {
    case createCalendarEvent, createReminder, saveChecklist, saveInformation, draftReply
    public var label: String {
        switch self {
        case .createCalendarEvent: "Add to Calendar"
        case .createReminder: "Create Reminder"
        case .saveChecklist: "Save Checklist"
        case .saveInformation: "Save Information"
        case .draftReply: "Draft Reply"
        }
    }
    public var icon: String {
        switch self {
        case .createCalendarEvent: "calendar.badge.plus"
        case .createReminder: "checklist"
        case .saveChecklist: "checkmark.square"
        case .saveInformation: "tray.and.arrow.down"
        case .draftReply: "square.and.pencil"
        }
    }
}
public struct ExtractedDate: Codable, Sendable, Equatable {
    public let rawText: String
    public let iso8601: String?
}
public struct ChecklistItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String { text }
    public let text: String
}
public struct ProposedAction: Codable, Identifiable, Sendable, Equatable {
    public var id: ProposedActionType { type }
    public let type: ProposedActionType
    public let title: String
    public let explanation: String
}
public struct ActionProposal: Codable, Sendable, Equatable {
    public let category: ContentCategory
    public let title: String
    public let summary: String
    public let dates: [ExtractedDate]
    public let locations: [String]
    public let people: [String]
    public let checklist: [ChecklistItem]
    public let proposedActions: [ProposedAction]
}
// Only OutputValidator can construct this capability. Never decode it from disk.
public struct ValidatedProposal: Sendable {
    public let value: ActionProposal
    init(_ value: ActionProposal) { self.value = value }
}
public enum SourceKind: String, Codable, Sendable { case text, image, pdf, url }
public enum AnalysisStatus: String, Codable, Sendable { case pending, processing, ready, failed }
public struct InboxItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let kind: SourceKind
    public let receivedAt: Date
    public var status: AnalysisStatus
    public var proposal: ActionProposal?
    public var failure: String?
    public init(id: UUID = UUID(), kind: SourceKind) {
        self.id = id; self.kind = kind; receivedAt = Date(); status = .pending
    }
}
public struct SavedChecklistItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public var completed: Bool
    public init(text: String) { id = UUID(); self.text = text; completed = false }
}
public struct SavedItem: Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let body: String
    public var checklist: [SavedChecklistItem]
    public let createdAt: Date
    public init(id: UUID, title: String, body: String, checklist: [SavedChecklistItem] = []) {
        self.id = id; self.title = title; self.body = body; self.checklist = checklist; createdAt = Date()
    }
}
public struct AnalysisInput: Sendable {
    public let text: String
    public init(text: String) throws { self.text = try InputValidator.text(text) }
}
public enum PrivateActionError: String, Error, LocalizedError, Sendable {
    case invalidInput, tooLarge, invalidOutput, invalidDate, unsafeURL, missingModel, corruptModel
    case busy, cancelled, timedOut, lowMemory, tooHot, permissionDenied, alreadyPerformed, unavailable
    public var errorDescription: String? {
        switch self {
        case .invalidInput: "This content could not be read safely. Try sharing text or a smaller file."
        case .tooLarge: "This content exceeds the analysis limit. Share a smaller selection."
        case .invalidOutput: "Local AI returned an invalid result. Nothing was executed. Try analyzing again."
        case .invalidDate: "Confirm a valid date and time before continuing."
        case .unsafeURL: "Only ordinary HTTPS or HTTP website addresses are accepted."
        case .missingModel: "Local AI model isn’t installed. Download it in Settings."
        case .corruptModel: "Model verification failed. Delete the model and download it again."
        case .busy: "Another local operation is still running."
        case .cancelled: "Analysis cancelled."
        case .timedOut: "Analysis took too long. Try a shorter selection."
        case .lowMemory: "This model requires more available memory. Close other apps or try the smaller model."
        case .tooHot: "Your iPhone needs to cool down before local analysis can continue."
        case .permissionDenied: "Access was denied. You can change this in iPhone Settings."
        case .alreadyPerformed: "This action was already submitted. Check the destination before creating another."
        case .unavailable: "This operation is unavailable."
        }
    }
}
