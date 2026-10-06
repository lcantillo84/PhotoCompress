import Foundation

struct CompressionResult {
    /// Final JPEG bytes, metadata included per the policy used.
    let data: Data
    /// JPEG quality of the winning encode, 0...1.
    let quality: Double
    /// Total encodes performed across all search rounds.
    let iterations: Int
    /// Output width / original width. 1.0 means no downscaling was needed.
    let scale: Double
    let originalBytes: Int
    let pixelWidth: Int
    let pixelHeight: Int

    var finalBytes: Int { data.count }
}

enum CompressionError: Error, Equatable {
    case unreadableSource
    case decodeFailed
    case encodeFailed
    case downscaleFailed
    /// Even at the minimum dimension and quality the target could not be met.
    case targetUnreachable
}
