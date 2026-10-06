import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Compresses a photo to the highest JPEG quality that fits a byte budget.
///
/// Never routes through `UIImage`: decoding and encoding stay in ImageIO so the
/// source's metadata survives. All search encodes go to in-memory buffers; nothing
/// touches disk. Exactly one decoded bitmap is held at a time.
enum CompressionEngine {
    /// Below this quality we downscale instead of degrading further.
    static let minQuality = 0.1
    /// Stop early once a fit lands within this fraction under the target.
    static let tolerance = 0.03
    static let downscaleStep = 0.9
    static let minDimension = 32

    private static let ciContext = CIContext()

    static func compress(
        sourceURL: URL,
        targetBytes: Int,
        metadata: MetadataPolicy = .preserveAll
    ) throws -> CompressionResult {
        guard targetBytes > 0,
              let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              CGImageSourceGetCount(source) > 0,
              let rawProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { throw CompressionError.unreadableSource }

        let originalBytes = (try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        var image: CGImage = try autoreleasepool {
            let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            guard let decoded = CGImageSourceCreateImageAtIndex(source, 0, options) else {
                throw CompressionError.decodeFailed
            }
            return decoded
        }
        let originalWidth = image.width
        var iterations = 0

        while true {
            let props = metadata.properties(from: rawProps, pixelWidth: image.width, pixelHeight: image.height)

            if let (data, quality) = try search(image: image, properties: props, target: targetBytes, iterations: &iterations) {
                return CompressionResult(
                    data: data,
                    quality: quality,
                    iterations: iterations,
                    scale: Double(image.width) / Double(originalWidth),
                    originalBytes: originalBytes,
                    pixelWidth: image.width,
                    pixelHeight: image.height
                )
            }

            let newWidth = Int((Double(image.width) * downscaleStep).rounded())
            let newHeight = Int((Double(image.height) * downscaleStep).rounded())
            guard min(newWidth, newHeight) >= minDimension else { throw CompressionError.targetUnreachable }
            // Replacing `image` releases the previous bitmap before the next round.
            image = try autoreleasepool { try downscale(image, toWidth: newWidth, height: newHeight) }
        }
    }

    /// Binary search on quality in [minQuality, 1]. Returns nil if even minQuality is over target,
    /// so the caller can downscale without burning a full search at a size that can't fit.
    ///
    /// Searches whole percent steps: ImageIO's output size is a staircase in quality (identical
    /// bytes for neighbouring values, then a jump), so sub-percent resolution only wastes encodes.
    private static func search(
        image: CGImage,
        properties: [CFString: Any],
        target: Int,
        iterations: inout Int
    ) throws -> (Data, Double)? {
        var low = Int((minQuality * 100).rounded())
        var high = 100

        let floor = try autoreleasepool { try encode(image, properties: properties, quality: Double(low) / 100) }
        iterations += 1
        guard floor.count <= target else { return nil }
        var best = (floor, Double(low) / 100)

        while high - low > 1 {
            let mid = (low + high) / 2
            let quality = Double(mid) / 100
            let data = try autoreleasepool { try encode(image, properties: properties, quality: quality) }
            iterations += 1

            if data.count <= target {
                best = (data, quality)
                low = mid
                if Double(data.count) >= Double(target) * (1 - tolerance) { break }
            } else {
                high = mid
            }
        }
        return best
    }

    private static func encode(_ image: CGImage, properties: [CFString: Any], quality: Double) throws -> Data {
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CompressionError.encodeFailed
        }
        var props = properties
        props[kCGImageDestinationLossyCompressionQuality] = quality
        CGImageDestinationAddImage(destination, image, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CompressionError.encodeFailed }
        return buffer as Data
    }

    private static func downscale(_ image: CGImage, toWidth width: Int, height: Int) throws -> CGImage {
        let input = CIImage(cgImage: image)
        let vertical = Double(height) / Double(image.height)
        let horizontal = Double(width) / Double(image.width)

        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = input
        filter.scale = Float(vertical)
        filter.aspectRatio = Float(horizontal / vertical)

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let output = filter.outputImage,
              let scaled = ciContext.createCGImage(
                output,
                from: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBA8,
                colorSpace: colorSpace
              )
        else { throw CompressionError.downscaleFailed }
        return scaled
    }
}
