import Foundation
import Photos

/// Adds compressed photos to the library as new assets. Add-only access: the app can't read,
/// change or delete anything already there.
enum PhotoSaver {
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    /// Saves the file's bytes untouched, so the metadata the engine wrote is what Photos stores.
    static func save(fileURL: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = fileURL.lastPathComponent
            PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: fileURL, options: options)
        }
    }
}
