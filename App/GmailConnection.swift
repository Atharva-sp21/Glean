import Foundation
import AuthenticationServices
import CryptoKit
import UIKit
import Observation

struct GmailMessage: Decodable, Identifiable {
    let id: String
    let snippet: String?
    let payload: Part?
    struct Header: Decodable { let name: String; let value: String }
    struct Body: Decodable { let data: String? }
    struct Part: Decodable {
        let mimeType: String?
        let filename: String?
        let headers: [Header]?
        let body: Body?
        let parts: [Part]?
        var plainText: String {
            guard (filename ?? "").isEmpty else { return "" }
            if mimeType == "text/plain", (filename ?? "").isEmpty, let raw = body?.data {
                let base = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                return Data(base64Encoded: base + String(repeating: "=", count: (4 - base.count % 4) % 4)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            }
            return (parts ?? []).map(\.plainText).filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }
    func header(_ name: String) -> String { payload?.headers?.first { $0.name.lowercased() == name.lowercased() }?.value ?? "" }
    var title: String { header("Subject").isEmpty ? "(No subject)" : header("Subject") }
    var importText: String {
        "Subject: \(title)\nFrom: \(header("From"))\nDate: \(header("Date"))\n\n\(payload?.plainText ?? "")"
    }
}

// User-initiated read-only connection. Tokens and previews exist only in memory.
// No background sync, remote HTML, attachments, sending, or model-driven requests.
@MainActor @Observable final class GmailConnection: NSObject, ASWebAuthenticationPresentationContextProviding {
    var messages: [GmailMessage] = []
    var busy = false
    var connected = false
    var error: String?
    private var generation = UUID()
    private var token: String?
    private var expiry = Date.distantPast
    private var auth: ASWebAuthenticationSession?
    private let scope = "https://www.googleapis.com/auth/gmail.readonly"
    private let network = URLSession(configuration: .ephemeral, delegate: NoGmailRedirects(), delegateQueue: nil)
    var clientID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GleanGoogleClientID") as? String,
              id.range(of: #"^[0-9]+-[A-Za-z0-9]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil else { return nil }
        return id
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
    private func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw Failure.connection }
        return Self.base64(Data(bytes))
    }
    private static func base64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    enum Failure: Error { case connection, expired, tooLarge, permission, noText }
    func connect() async {
        guard !busy, let clientID else { return }
        let current = generation
        busy = true; error = nil
        defer { busy = false; auth = nil }
        do {
            let verifier = try random(), state = try random()
            let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
            let redirect = scheme + ":/oauth2redirect"
            var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
            url.queryItems = ["client_id": clientID, "redirect_uri": redirect, "response_type": "code", "scope": scope,
                              "state": state, "code_challenge": Self.base64(Data(SHA256.hash(data: Data(verifier.utf8)))),
                              "code_challenge_method": "S256", "prompt": "select_account"].map { URLQueryItem(name: $0.key, value: $0.value) }
            let callback: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: url.url!, callbackURLScheme: scheme) { callback, failure in
                    if let callback { continuation.resume(returning: callback) }
                    else { continuation.resume(throwing: failure ?? Failure.connection) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                auth = session
                if !session.start() { continuation.resume(throwing: Failure.connection) }
            }
            let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard callback.scheme == scheme, callback.path == "/oauth2redirect",
                  query.filter({ $0.name == "state" }).count == 1,
                  query.first(where: { $0.name == "state" })?.value == state,
                  let code = query.first(where: { $0.name == "code" })?.value else { throw Failure.connection }
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let fields = ["client_id": clientID, "code": code, "code_verifier": verifier, "redirect_uri": redirect, "grant_type": "authorization_code"]
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            request.httpBody = fields.map { $0.key + "=" + ($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }.joined(separator: "&").data(using: .utf8)
            struct Tokens: Decodable { let access_token: String; let expires_in: Double; let scope: String? }
            let result = try JSONDecoder().decode(Tokens.self, from: await requestData(request))
            guard generation == current else { return }
            guard result.scope?.split(separator: " ").contains(Substring(scope)) == true else { throw Failure.permission }
            token = result.access_token; expiry = Date().addingTimeInterval(result.expires_in - 30); connected = true
        } catch {
            guard generation == current else { return }
            self.error = "Google sign-in did not finish. Check the OAuth configuration and Gmail permission, then try again."
        }
    }
    func disconnect() {
        generation = UUID(); auth?.cancel(); auth = nil
        token = nil; expiry = .distantPast; connected = false; messages = []; error = nil
    }
    func load() async {
        guard !busy else { return }
        let current = generation
        busy = true; error = nil
        defer { busy = false }
        do {
            struct Page: Decodable { struct Ref: Decodable { let id: String }; let messages: [Ref]? }
            let page = try JSONDecoder().decode(Page.self, from: await get("messages", query: [URLQueryItem(name: "maxResults", value: "20"), URLQueryItem(name: "labelIds", value: "INBOX")]))
            var results: [GmailMessage] = []
            for ref in page.messages ?? [] {
                try Task.checkCancellation()
                let data = try await get("messages/" + ref.id, query: [URLQueryItem(name: "format", value: "metadata"), URLQueryItem(name: "metadataHeaders", value: "Subject"), URLQueryItem(name: "metadataHeaders", value: "From"), URLQueryItem(name: "metadataHeaders", value: "Date")])
                results.append(try JSONDecoder().decode(GmailMessage.self, from: data))
            }
            guard generation == current else { return }
            messages = results
        } catch { if generation == current { handle(error) } }
    }
    func selectedText(_ id: String) async -> String? {
        guard !busy else { return nil }
        let current = generation
        busy = true; error = nil; defer { busy = false }
        do {
            let message = try JSONDecoder().decode(GmailMessage.self, from: await get("messages/" + id, query: [URLQueryItem(name: "format", value: "full")]))
            guard generation == current else { return nil }
            guard !(message.payload?.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else { throw Failure.noText }
            guard message.importText.count <= 12_000 else { throw Failure.tooLarge }
            return message.importText
        } catch { if generation == current { handle(error) }; return nil }
    }
    private func handle(_ failure: Error) {
        switch failure {
        case Failure.expired: disconnect(); error = "Your Gmail session expired. Sign in again."
        case Failure.noText: error = "This email has no supported plain-text body. Copy its text from Gmail or share a screenshot instead."
        case Failure.tooLarge: error = "This email is too large. Copy just the relevant text into Glean."
        default: error = "Could not read Gmail. Check your connection, Gmail API setup and read permission, then retry."
        }
    }
    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard let token, Date() < expiry else { throw Failure.expired }
        guard path.range(of: #"^messages(/[A-Za-z0-9_-]+)?$"#, options: .regularExpression) != nil else { throw Failure.connection }
        var url = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/" + path)!
        url.queryItems = query
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        return try await requestData(request)
    }
    private func requestData(_ original: URLRequest) async throws -> Data {
        var request = original; request.timeoutInterval = 30
        let (bytes, response) = try await network.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.connection }
        if http.statusCode == 401 { throw Failure.expired }
        guard (200..<300).contains(http.statusCode) else { throw Failure.connection }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw Failure.tooLarge }
            data.append(byte)
        }
        return data
    }
}
private final class NoGmailRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}
