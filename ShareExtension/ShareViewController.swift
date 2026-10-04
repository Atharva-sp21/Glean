import UIKit
import UniformTypeIdentifiers
import ImageIO
import PrivateActionCore

final class ShareViewController: UIViewController {
    private let message = UILabel()
    private var task: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let symbol = UIImageView(image: UIImage(systemName: "tray.and.arrow.down.fill")); symbol.tintColor = .systemTeal
        symbol.contentMode = .scaleAspectFit
        let title = UILabel(); title.text = "Glean"; title.font = .preferredFont(forTextStyle: .title1)
        message.text = "Saving securely on your iPhone…"; message.numberOfLines = 0; message.textAlignment = .center
        let done = UIButton(type: .system); done.setTitle("Done", for: .normal)
        done.addTarget(self, action: #selector(finish), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [symbol, title, message, done]); stack.axis = .vertical; stack.spacing = 24; stack.alignment = .center
        view.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.centerYAnchor.constraint(equalTo: view.centerYAnchor), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32), symbol.heightAnchor.constraint(equalToConstant: 56)])
        task = Task {
            do {
                let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
                let providers = extensionItems.flatMap { $0.attachments ?? [] }
                guard !providers.isEmpty, providers.count <= 5 else { throw PrivateActionError.tooLarge }
                let store = try SharedContainer.inbox()
                // v1 takes one item to keep extension memory and behavior predictable.
                guard providers.count == 1, let provider = providers.first else { throw PrivateActionError.tooLarge }
                let (data, kind) = try await SharedInboxWriter.load(provider, suppliedTitle: extensionItems.first?.attributedTitle?.string, suppliedText: extensionItems.first?.attributedContentText?.string)
                try Task.checkCancellation()
                let item = try await store.importData(data, kind: kind)
                SharedContainer.queueSharedItem(item.id)
                message.text = "Saved to Glean.\n\nTap Done, then open Glean. Analysis starts automatically, and you review any suggested action before saving."
            } catch { message.text = "Couldn’t save this item. Share one image, PDF, website address or text selection (up to 20 MB)." }
        }
    }
    @objc private func finish() { task?.cancel(); extensionContext?.completeRequest(returningItems: nil) }
}

@MainActor enum SharedInboxWriter {
    static func load(_ provider: NSItemProvider, suppliedTitle: String? = nil, suppliedText: String? = nil) async throws -> (Data, SourceKind) {
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            let data = try await file(provider, type: .pdf)
            guard data.starts(with: Data("%PDF-".utf8)) else { throw PrivateActionError.invalidInput }
            return (data, .pdf)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let data = try await file(provider, type: .image)
            // Re-encode the bounded thumbnail to strip EXIF/GPS and large source pixels.
            let image = try OCRService.downsample(data)
            let result = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else { throw PrivateActionError.invalidInput }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw PrivateActionError.invalidInput }
            return (result as Data, .image)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let url: URL = try await withCheckedThrowingContinuation { continuation in
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let url = value as? URL { continuation.resume(returning: url) }
                    else { continuation.resume(throwing: PrivateActionError.invalidInput) }
                }
            }
            _ = try InputValidator.webURL(url.absoluteString)
            let title = (suppliedTitle ?? provider.suggestedName).map { String($0.prefix(200)) }
            let text = try suppliedText.flatMap { value in value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : try InputValidator.text(value) }
            return (try JSONEncoder().encode(SharedURL(url: url.absoluteString, title: title, text: text)), .url)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let text: String
            if let data = try? await file(provider, type: .plainText), let value = String(data: data, encoding: .utf8) {
                text = value
            } else {
                try Task.checkCancellation()
                text = try await withCheckedThrowingContinuation { continuation in
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let value = item as? String { continuation.resume(returning: value) }
                        else { continuation.resume(throwing: PrivateActionError.invalidInput) }
                    }
                }
            }
            return (Data(try InputValidator.text(text).utf8), .text)
        }
        throw PrivateActionError.invalidInput
    }
    static func file(_ provider: NSItemProvider, type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                do {
                    if let error { throw error }
                    guard let url else { throw PrivateActionError.invalidInput }
                    let data = try SecureFiles.read(url, limit: type == .plainText ? SecurityPolicy.maxTextBytes : SecurityPolicy.maxInputBytes)
                    try InputValidator.byteCount(data.count)
                    continuation.resume(returning: data)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
