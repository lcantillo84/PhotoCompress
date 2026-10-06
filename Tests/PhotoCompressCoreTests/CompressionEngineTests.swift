import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PhotoCompressCore

final class CompressionEngineTests: XCTestCase {
    static let captureDate = "2024:03:15 14:22:09"
    static let cameraModel = "iPhone 15 Pro"

    static let sampleURL: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pc-sample-\(UUID().uuidString).jpg")
        try! makeSamplePhoto(at: url, width: 4032, height: 3024)
        return url
    }()

    override class func tearDown() {
        try? FileManager.default.removeItem(at: sampleURL)
    }

    func testTarget500KB() throws { try run(label: "500KB", target: 500_000, minFill: 0.9) }
    func testTarget2MB() throws { try run(label: "2MB", target: 2_000_000) }

    func testTinyTargetForcesDownscale() throws {
        let result = try run(label: "40KB (forces downscale)", target: 40_000)
        XCTAssertLessThan(result.scale, 1.0, "expected the engine to downscale")
        XCTAssertLessThan(result.pixelWidth, 4032)
    }

    func testStripPolicyRemovesGPSAndEXIFButKeepsOrientation() throws {
        let result = try CompressionEngine.compress(
            sourceURL: Self.sampleURL, targetBytes: 2_000_000, metadata: .stripSensitive)
        let props = try properties(of: result.data)
        XCTAssertNil(props[kCGImagePropertyGPSDictionary])
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
        XCTAssertEqual(props[kCGImagePropertyOrientation] as? Int, 6)
    }

    /// iPhone photos are HEIC in Display P3. Output is JPEG; EXIF must survive and color space must stay wide-gamut.
    func testHEICDisplayP3Source() throws {
        let heic = FileManager.default.temporaryDirectory.appendingPathComponent("pc-\(UUID().uuidString).heic")
        defer { try? FileManager.default.removeItem(at: heic) }
        try Self.makeSamplePhoto(at: heic, width: 4032, height: 3024, type: .heic, colorSpaceName: CGColorSpace.displayP3)

        let result = try CompressionEngine.compress(sourceURL: heic, targetBytes: 500_000)
        let props = try properties(of: result.data)
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        print("[HEIC P3] original \(result.originalBytes) B | final \(result.finalBytes) B | quality \(result.quality) | scale \(result.scale) | profile \(props[kCGImagePropertyProfileName] ?? "none")")

        XCTAssertLessThanOrEqual(result.finalBytes, 500_000)
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal] as? String, Self.captureDate)
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFModel] as? String, Self.cameraModel)
        XCTAssertEqual(props[kCGImagePropertyOrientation] as? Int, 6)
        XCTAssertTrue((props[kCGImagePropertyProfileName] as? String)?.contains("P3") == true, "color profile lost")
    }

    func testUnreadableSourceThrows() {
        let bogus = FileManager.default.temporaryDirectory.appendingPathComponent("nope.jpg")
        XCTAssertThrowsError(try CompressionEngine.compress(sourceURL: bogus, targetBytes: 1000)) {
            XCTAssertEqual($0 as? CompressionError, .unreadableSource)
        }
    }

    // MARK: - Harness

    @discardableResult
    private func run(label: String, target: Int, minFill: Double = 0) throws -> CompressionResult {
        let result = try CompressionEngine.compress(sourceURL: Self.sampleURL, targetBytes: target)

        print("""
        [\(label)] target \(target) B | original \(result.originalBytes) B | final \(result.finalBytes) B \
        (\(String(format: "%.1f", Double(result.finalBytes) / Double(target) * 100))% of target) | \
        quality \(String(format: "%.4f", result.quality)) | iterations \(result.iterations) | \
        scale \(String(format: "%.3f", result.scale)) | \(result.pixelWidth)x\(result.pixelHeight)
        """)

        XCTAssertLessThanOrEqual(result.finalBytes, target)
        XCTAssertGreaterThanOrEqual(Double(result.finalBytes), Double(target) * minFill, "left too much budget unused")

        let props = try properties(of: result.data)
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal] as? String, Self.captureDate)
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFModel] as? String, Self.cameraModel)
        XCTAssertEqual(props[kCGImagePropertyOrientation] as? Int, 6)
        XCTAssertNotNil(props[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, result.pixelWidth)
        return result
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    /// Photo-like synthetic image: smooth gradients and patterns plus mild noise, with EXIF.
    static func makeSamplePhoto(
        at url: URL, width: Int, height: Int,
        type: UTType = .jpeg, colorSpaceName: CFString = CGColorSpace.sRGB
    ) throws {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var rng = SystemRandomNumberGenerator()
        for y in 0..<height {
            for x in 0..<width {
                let fx = Double(x) / Double(width), fy = Double(y) / Double(height)
                let base = 0.5 + 0.25 * sin(fx * 23) * cos(fy * 17) + 0.2 * (fx - fy)
                let i = (y * width + x) * 4
                for c in 0..<3 {
                    let noise = Double(Int.random(in: -12...12, using: &rng))
                    let v = (base + 0.1 * sin(fx * 60 + Double(c) * 2) * sin(fy * 45)) * 255 + noise
                    pixels[i + c] = UInt8(max(0, min(255, v)))
                }
            }
        }
        let image: CGImage = pixels.withUnsafeMutableBytes { raw in
            let ctx = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: colorSpaceName)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            return ctx.makeImage()!
        }

        let props: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: cameraModel,
                kCGImagePropertyTIFFOrientation: 6,
            ],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: captureDate],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 25.7617, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 80.1918, kCGImagePropertyGPSLongitudeRef: "W",
            ],
            kCGImageDestinationLossyCompressionQuality: 0.95,
        ]
        let dest = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        precondition(CGImageDestinationFinalize(dest))
    }
}
