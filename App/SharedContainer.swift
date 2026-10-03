import Foundation
import PrivateActionCore

enum SharedContainer {
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
