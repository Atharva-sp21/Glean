import Foundation

public enum SecureFiles {
    public static func directory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try protect(url)
    }
    public static func protect(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
        var resource = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try resource.setResourceValues(values)
    }
    public static func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
        try protect(url)
    }
    public static func read(_ url: URL, limit: Int) throws -> Data {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              let size = attrs[.size] as? NSNumber, size.intValue <= limit else { throw PrivateActionError.tooLarge }
        return try Data(contentsOf: url)
    }
}

// Each item is published via a same-volume atomic directory rename. No shared mutable index.
public actor InboxStore {
    public let root: URL
    public init(root: URL) throws { self.root = root; try SecureFiles.directory(root) }
    public func payloadURL(_ item: InboxItem) -> URL { folder(item.id).appendingPathComponent("source.\(item.kind.rawValue)") }
    private func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func importData(_ data: Data, kind: SourceKind) throws -> InboxItem {
        try InputValidator.byteCount(data.count)
        let items = try list()
        guard items.count < SecurityPolicy.maxInboxItems else { throw PrivateActionError.tooLarge }
        let used = items.reduce(0) { sum, item in
            let url = payloadURL(item)
            return sum + ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0)
        }
        guard used + data.count <= SecurityPolicy.maxInboxBytes else { throw PrivateActionError.tooLarge }
        let item = InboxItem(kind: kind)
        let staging = root.appendingPathComponent(".import-\(item.id)", isDirectory: true)
        try SecureFiles.directory(staging)
        defer { try? FileManager.default.removeItem(at: staging) }
        try SecureFiles.write(data, to: staging.appendingPathComponent("source.\(kind.rawValue)"))
        try SecureFiles.write(JSONEncoder().encode(item), to: staging.appendingPathComponent("item.json"))
        try FileManager.default.moveItem(at: staging, to: folder(item.id))
        return item
    }
    public func list() throws -> [InboxItem] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).compactMap { url in
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            let item = try JSONDecoder().decode(InboxItem.self, from: SecureFiles.read(url.appendingPathComponent("item.json"), limit: 64_000))
            guard item.id == id else { throw PrivateActionError.invalidInput }
            return item
        }.sorted { $0.receivedAt > $1.receivedAt }
    }
    public func update(_ item: InboxItem) throws {
        guard FileManager.default.fileExists(atPath: folder(item.id).path) else { throw PrivateActionError.invalidInput }
        try SecureFiles.write(JSONEncoder().encode(item), to: folder(item.id).appendingPathComponent("item.json"))
    }
    public func finish(_ item: InboxItem, proposal: ValidatedProposal) throws {
        var ready = item; ready.status = .ready; ready.proposal = proposal.value; ready.failure = nil
        try update(ready)
        try removeSource(item)
    }
    public func removeSource(_ item: InboxItem) throws {
        let url = payloadURL(item)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    public func delete(_ id: UUID) throws { try FileManager.default.removeItem(at: folder(id)) }
    public func deleteAll() throws {
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) { try FileManager.default.removeItem(at: url) }
    }
    public func recoverAndExpire(now: Date = Date()) throws {
        for var item in try list() {
            if item.status == .ready { try removeSource(item) }
            else if now.timeIntervalSince(item.receivedAt) > 24 * 3600 {
                try removeSource(item); item.status = .failed; item.failure = "Source expired after 24 hours. Share it again."; try update(item)
            } else if item.status == .processing {
                item.status = .failed; item.failure = "Analysis was interrupted. You can retry."; try update(item)
            }
        }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) where url.lastPathComponent.hasPrefix(".import-") {
            let date = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? now
            if now.timeIntervalSince(date) > 3600 { try FileManager.default.removeItem(at: url) }
        }
    }
}
