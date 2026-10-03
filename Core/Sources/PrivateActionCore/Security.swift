import Foundation
import CryptoKit

public enum SecurityPolicy {
    public static let maxInputBytes = 20 * 1024 * 1024
    public static let maxTextBytes = 48_000
    public static let maxTextCharacters = 12_000
    public static let maxOutputBytes = 24_000
    public static let maxPDFPages = 10
    public static let maxImagePixels = 48_000_000
    public static let ocrDimension = 2048
    public static let maxInputTokens = 3072
    public static let maxOutputTokens = 512
    public static let generationTimeout: TimeInterval = 45
    public static let maxInboxItems = 100
    public static let maxInboxBytes = 200 * 1024 * 1024
    public static let maxSavedItems = 500
}
public enum InputValidator {
    public static func byteCount(_ count: Int) throws {
        guard count > 0, count <= SecurityPolicy.maxInputBytes else { throw PrivateActionError.tooLarge }
    }
    public static func text(_ value: String) throws -> String {
        guard value.utf8.count <= SecurityPolicy.maxTextBytes, value.count <= SecurityPolicy.maxTextCharacters else { throw PrivateActionError.tooLarge }
        let clean = value.precomposedStringWithCanonicalMapping.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) || $0 == "\n" || $0 == "\t"
        }.filter { ![0x202A,0x202B,0x202C,0x202D,0x202E,0x2066,0x2067,0x2068,0x2069].contains($0.value) }
        let result = String(String.UnicodeScalarView(clean)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw PrivateActionError.invalidInput }
        return result
    }
    public static func webURL(_ string: String) throws -> URL {
        guard string.utf8.count <= 2048, !string.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }),
              let parts = URLComponents(string: string), let scheme = parts.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil, let url = parts.url else { throw PrivateActionError.unsafeURL }
        return url
    }
}
public enum OutputValidator {
    public static func decode(_ data: Data) throws -> ValidatedProposal {
        guard data.count <= SecurityPolicy.maxOutputBytes else { throw PrivateActionError.tooLarge }
        do {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw PrivateActionError.invalidOutput }
            try keys(root, ["category","title","summary","dates","locations","people","checklist","proposedActions"])
            for (field, allowed) in [("dates", ["rawText", "iso8601"]), ("checklist", ["text"]), ("proposedActions", ["type","title","explanation"])] {
                guard let rows = root[field] as? [[String: Any]], rows.count <= 20 else { throw PrivateActionError.invalidOutput }
                for row in rows { try keys(row, Set(allowed)) }
            }
            let value = try JSONDecoder().decode(ActionProposal.self, from: data)
            try field(value.title, max: 160, empty: false); try field(value.summary, max: 2000)
            guard value.dates.count <= 8, value.locations.count <= 8, value.people.count <= 12, value.checklist.count <= 20, value.proposedActions.count <= 5 else { throw PrivateActionError.invalidOutput }
            for date in value.dates {
                try field(date.rawText, max: 200, empty: false)
                if let iso = date.iso8601 { _ = try parseDate(iso) }
            }
            for string in value.locations + value.people { try field(string, max: 300, empty: false) }
            for item in value.checklist { try field(item.text, max: 300, empty: false) }
            guard Set(value.checklist.map(\.text)).count == value.checklist.count,
                  Set(value.proposedActions.map(\.type)).count == value.proposedActions.count else { throw PrivateActionError.invalidOutput }
            for action in value.proposedActions {
                try field(action.title, max: 160, empty: false); try field(action.explanation, max: 400)
                if action.type == .saveChecklist && value.checklist.isEmpty { throw PrivateActionError.invalidOutput }
            }
            return ValidatedProposal(value)
        } catch let error as PrivateActionError { throw error }
        catch { throw PrivateActionError.invalidOutput }
    }
    public static func validate(_ value: ActionProposal) throws -> ValidatedProposal { try decode(JSONEncoder().encode(value)) }
    static func keys(_ object: [String: Any], _ allowed: Set<String>) throws {
        guard Set(object.keys) == allowed else { throw PrivateActionError.invalidOutput }
    }
    public static func field(_ value: String, max: Int, empty: Bool = true) throws {
        guard value.count <= max, (empty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
              value == value.precomposedStringWithCanonicalMapping,
              !value.unicodeScalars.contains(where: {
                  (CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t") || [0x202A,0x202B,0x202C,0x202D,0x202E,0x2066,0x2067,0x2068,0x2069].contains($0.value)
              }), !value.contains("<"), !value.contains(">") else { throw PrivateActionError.invalidOutput }
        // Text is rendered only by native Text/TextEditor, never HTML or a link renderer.
    }
    public static func parseDate(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // Require a canonical UTC timestamp; round-trip rejects impossible calendar dates.
        guard string.count == 20, string.hasSuffix("Z"), let date = formatter.date(from: string), formatter.string(from: date) == string else { throw PrivateActionError.invalidDate }
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        guard (2000...2100).contains(year) else { throw PrivateActionError.invalidDate }
        return date
    }
}
public struct ModelAsset: Codable, Sendable {
    public let path: String
    public let size: Int64
    public let sha256: String
    public init(path: String, size: Int64, sha256: String) { self.path = path; self.size = size; self.sha256 = sha256 }
}
public struct ModelManifest: Codable, Identifiable, Sendable {
    public var id: String { repo }
    public let repo: String
    public let revision: String
    public let name: String
    public let bits: Int
    public let license: String
    public let experimental: Bool
    public let files: [ModelAsset]
    public var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }
    public var directoryName: String { repo.replacingOccurrences(of: "/", with: "--") + "-" + revision }
}
public enum ModelAssetVerifier {
    public static func verify(_ url: URL, asset: ModelAsset) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.size] as? NSNumber)?.int64Value == asset.size else { throw PrivateActionError.corruptModel }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            try Task.checkCancellation(); hash.update(data: chunk)
        }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == asset.sha256 else { throw PrivateActionError.corruptModel }
    }
    public static func verifyDirectory(_ directory: URL, manifest: ModelManifest) throws {
        let expected = Set(manifest.files.map(\.path))
        guard Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)) == expected else { throw PrivateActionError.corruptModel }
        for asset in manifest.files {
            guard !asset.path.contains("/"), !asset.path.contains("..") else { throw PrivateActionError.corruptModel }
            try verify(directory.appendingPathComponent(asset.path), asset: asset)
        }
    }
}
