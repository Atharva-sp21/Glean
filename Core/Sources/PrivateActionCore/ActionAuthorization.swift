import Foundation
import CryptoKit

public struct ActionReview: Sendable {
    public let itemID: UUID
    public let type: ProposedActionType
    public var title: String
    public var body: String
    public var start: Date?
    public var end: Date?
    public var destinationID: String?
    public var dateConfirmed = false
    public init(itemID: UUID, type: ProposedActionType, title: String, body: String) {
        self.itemID = itemID; self.type = type; self.title = title; self.body = body
    }
}
public struct ApprovedAction: Sendable {
    public let review: ActionReview
    public var key: String { review.itemID.uuidString + ":" + review.type.rawValue }
    fileprivate init(_ review: ActionReview) { self.review = review }
}
public enum UserConfirmation {
    // Called only from an explicit confirmation button; model adapters cannot obtain an executor.
    public static func approve(_ review: ActionReview, proposal: ValidatedProposal) throws -> ApprovedAction {
        guard proposal.value.proposedActions.contains(where: { $0.type == review.type }) else { throw PrivateActionError.invalidOutput }
        try OutputValidator.field(review.title, max: 160, empty: false)
        try OutputValidator.field(review.body, max: 8000)
        if review.type == .saveChecklist {
            let lines = review.body.split(separator: "\n").map(String.init)
            guard !lines.isEmpty, lines.count <= 20 else { throw PrivateActionError.invalidOutput }
            for line in lines { try OutputValidator.field(line, max: 302, empty: false) }
        }
        if review.type == .createCalendarEvent {
            guard review.dateConfirmed, let start = review.start, let end = review.end,
                  start < end, end.timeIntervalSince(start) <= 7 * 86400,
                  review.destinationID?.isEmpty == false else { throw PrivateActionError.invalidDate }
        }
        if let start = review.start {
            let year = Calendar(identifier: .gregorian).component(.year, from: start)
            guard (2000...2100).contains(year), review.dateConfirmed else { throw PrivateActionError.invalidDate }
        }
        if review.type == .createReminder && review.destinationID?.isEmpty != false { throw PrivateActionError.invalidInput }
        return ApprovedAction(review)
    }
}
@MainActor public protocol ActionExecutor {
    func prepare() async throws
    func execute(_ action: ApprovedAction) async throws
}
// Durable at-most-once guard. A crash after reservation cannot silently duplicate a side effect.
// Uncertain outcomes deliberately stay blocked; the user checks Calendar/Reminders.
public actor ActionJournal {
    private let root: URL
    public init(root: URL) throws { self.root = root; try SecureFiles.directory(root) }
    private func file(_ key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(hash + ".json")
    }
    public func reserve(_ action: ApprovedAction) throws {
        let url = file(action.key)
        guard !FileManager.default.fileExists(atPath: url.path) else { throw PrivateActionError.alreadyPerformed }
        try SecureFiles.write(Data("{\"state\":\"submitted\"}".utf8), to: url)
    }
    public func complete(_ action: ApprovedAction) throws { try SecureFiles.write(Data("{\"state\":\"completed\"}".utf8), to: file(action.key)) }
    public func deleteAll() throws {
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) { try FileManager.default.removeItem(at: url) }
    }
}
@MainActor public final class ActionCoordinator {
    private let journal: ActionJournal
    private var inFlight = false
    public init(journal: ActionJournal) { self.journal = journal }
    public func perform(_ approved: ApprovedAction, executor: any ActionExecutor) async throws {
        guard !inFlight else { throw PrivateActionError.busy }
        inFlight = true; defer { inFlight = false }
        try await executor.prepare()
        try await journal.reserve(approved)
        try await executor.execute(approved)
        try await journal.complete(approved)
    }
}
