import Foundation
import PrivateActionCore

enum SharedContainer {
    private static var preferences: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PrivateActionAppGroup") as? String else { return nil }
        return UserDefaults(suiteName: group)
    }
    static func queueSharedItem(_ id: UUID) {
        preferences?.set(id.uuidString, forKey: "pendingSharedItem")
    }
    static func takeSharedItem() -> UUID? {
        guard let value = preferences?.string(forKey: "pendingSharedItem") else { return nil }
        preferences?.removeObject(forKey: "pendingSharedItem")
        return UUID(uuidString: value)
    }
    static func inbox() throws -> InboxStore {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PrivateActionAppGroup") as? String,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw PrivateActionError.unavailable
        }
        return try InboxStore(root: root.appendingPathComponent("Inbox", isDirectory: true))
    }
    static func privateRoot() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("PrivateAction", isDirectory: true)
        try SecureFiles.directory(root); return root
    }
}
