import Foundation
import ImageIO

/// Decides which source metadata is passed back into the encoder.
enum MetadataPolicy {
    /// Pass the full property dictionary through (default; competitors strip it).
    case preserveAll
    /// Remove location and camera/EXIF details. Orientation is kept so the image still displays upright.
    case stripSensitive

    /// Returns the properties to hand to `CGImageDestinationAddImage`, with pixel
    /// dimensions corrected for the image actually being written.
    func properties(
        from source: [CFString: Any],
        pixelWidth: Int,
        pixelHeight: Int
    ) -> [CFString: Any] {
        var props = source

        switch self {
        case .preserveAll:
            break
        case .stripSensitive:
            props[kCGImagePropertyGPSDictionary] = nil
            props[kCGImagePropertyExifDictionary] = nil
            props[kCGImagePropertyExifAuxDictionary] = nil
            props[kCGImagePropertyMakerAppleDictionary] = nil
            props[kCGImagePropertyIPTCDictionary] = nil
            if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                let orientation = tiff[kCGImagePropertyTIFFOrientation]
                tiff = [:]
                tiff[kCGImagePropertyTIFFOrientation] = orientation
                props[kCGImagePropertyTIFFDictionary] = tiff
            }
        }

        props[kCGImagePropertyPixelWidth] = pixelWidth
        props[kCGImagePropertyPixelHeight] = pixelHeight
        if var exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = pixelWidth
            exif[kCGImagePropertyExifPixelYDimension] = pixelHeight
            props[kCGImagePropertyExifDictionary] = exif
        }
        return props
    }
}
