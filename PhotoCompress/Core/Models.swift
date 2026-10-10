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

/// Upload limits offered as one-tap targets. Decimal units (1 MB = 1,000,000 B) so results
/// also fit limits that are measured in binary units.
enum SizePreset {
    static let all = [100_000, 300_000, 500_000, 1_000_000, 2_000_000, 10_000_000, 25_000_000]
    static let `default` = 2_000_000
}

enum SizeUnit: Int, CaseIterable {
    case kb = 1_000
    case mb = 1_000_000
}
