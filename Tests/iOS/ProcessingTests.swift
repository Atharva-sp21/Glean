import XCTest
import UIKit
import PDFKit
@testable import PrivateAction
import PrivateActionCore

final class ProcessingTests: XCTestCase {
    func testMalformedImageRejected() { XCTAssertThrowsError(try OCRService.downsample(Data("fake image".utf8))) }
    func testMalformedPDFRejected() { XCTAssertThrowsError(try PDFTextExtractor.extract(Data("%PDF-not-a-file".utf8))) }
    @MainActor func testOversizedPDFPageCountRejected() throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        let data = renderer.pdfData { context in
            for _ in 0..<11 { context.beginPage(); ("Test" as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil) }
        }
        XCTAssertThrowsError(try PDFTextExtractor.extract(data))
    }
    func testModelManifestDefaultAndPins() throws {
        let bundle = Bundle(for: AppEnvironment.self)
        let url = try XCTUnwrap(bundle.url(forResource: "ModelManifests", withExtension: "json"))
        let manifests = try JSONDecoder().decode([ModelManifest].self, from: Data(contentsOf: url))
        XCTAssertEqual(manifests.count, 3)
        XCTAssertEqual(manifests[0].repo, "mlx-community/Qwen3-1.7B-4bit")
        XCTAssertLessThan(manifests[0].totalBytes, 1_200_000_000)
        for manifest in manifests { XCTAssertEqual(manifest.revision.count, 40); for file in manifest.files { XCTAssertEqual(file.sha256.count, 64) } }
    }
}
