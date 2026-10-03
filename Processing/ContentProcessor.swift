import Foundation
import Vision
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import PrivateActionCore

struct ContentProcessor: Sendable {
    func process(_ item: InboxItem, url: URL) async throws -> AnalysisInput {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data = try SecureFiles.read(url, limit: SecurityPolicy.maxInputBytes)
            let text: String
            switch item.kind {
            case .text: guard let value = String(data: data, encoding: .utf8) else { throw PrivateActionError.invalidInput }; text = value
            case .url:
                let value = try JSONDecoder().decode(SharedURL.self, from: data)
                _ = try InputValidator.webURL(value.url)
                text = "Website metadata only (page not fetched):\n\(value.url)\n\(value.title ?? "")\n\(value.text ?? "")"
            case .image: text = try OCRService.recognize(data)
            case .pdf: text = try PDFTextExtractor.extract(data)
            }
            return try AnalysisInput(text: text)
        }
        return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    }
}
struct SharedURL: Codable { let url: String; let title: String?; let text: String? }

enum OCRService {
    static func downsample(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source), UTType(type as String)?.conforms(to: .image) == true,
              let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = info[kCGImagePropertyPixelWidth] as? Int, let height = info[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 20_000, height <= 20_000, width * height <= SecurityPolicy.maxImagePixels,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: SecurityPolicy.ocrDimension,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw PrivateActionError.invalidInput }
        return image
    }
    static func recognize(_ data: Data) throws -> String { try recognize(downsample(data)) }
    static func recognize(_ image: CGImage) throws -> String {
        try Task.checkCancellation()
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        return try InputValidator.text(text)
    }
}
enum PDFTextExtractor {
    static func extract(_ data: Data) throws -> String {
        guard data.starts(with: Data("%PDF-".utf8)), let document = PDFDocument(data: data), !document.isLocked,
              document.pageCount > 0 else { throw PrivateActionError.invalidInput }
        // Fail visibly instead of silently losing pages.
        guard document.pageCount <= SecurityPolicy.maxPDFPages else { throw PrivateActionError.tooLarge }
        var text = ""
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            let pageText: String = try autoreleasepool {
                guard let page = document.page(at: index) else { throw PrivateActionError.invalidInput }
                if let native = page.string, !native.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return native }
                let bounds = page.bounds(for: .mediaBox)
                guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else { throw PrivateActionError.invalidInput }
                let scale = min(CGFloat(SecurityPolicy.ocrDimension) / bounds.width, CGFloat(SecurityPolicy.ocrDimension) / bounds.height)
                let thumbnail = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                guard let image = thumbnail.cgImage else { throw PrivateActionError.invalidInput }
                return try OCRService.recognize(image)
            }
            text += pageText + "\n"
            guard text.count <= SecurityPolicy.maxTextCharacters else { throw PrivateActionError.tooLarge }
        }
        return try InputValidator.text(text)
    }
}
