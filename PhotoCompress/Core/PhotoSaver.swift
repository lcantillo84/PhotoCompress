import Foundation
import Photos

/// Adds compressed photos to the library as new assets, inside the app's own album.
/// Nothing already in the library is ever changed or deleted.
enum PhotoSaver {
    static let albumTitle = "Photo Compress"
    private static let albumKey = "albumIdentifier"

    /// Full access is needed only to create and fill the album; add-only can't touch albums.
    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Saves the file's bytes untouched, so the metadata the engine wrote is what Photos stores.
    /// Call off the main thread. If the album can't be used, the photo is still saved to the library.
    static func save(fileURL: URL) throws {
        if let album = album() {
            do {
                try create(fileURL, in: album)
                return
            } catch {
                UserDefaults.standard.removeObject(forKey: albumKey)
            }
        }
        try create(fileURL, in: nil)
    }

    private static func create(_ fileURL: URL, in album: PHAssetCollection?) throws {
        try PHPhotoLibrary.shared().performChangesAndWait {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = fileURL.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: options)
            if let album, let placeholder = request.placeholderForCreatedAsset {
                PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
            }
        }
    }

    /// Finds the app's album (by saved identifier, then by title) or creates it.
    private static func album() -> PHAssetCollection? {
        if let id = UserDefaults.standard.string(forKey: albumKey),
           let found = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject {
            return found
        }
        let byTitle = PHFetchOptions()
        byTitle.predicate = NSPredicate(format: "title = %@", albumTitle)
        if let found = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: byTitle).firstObject {
            UserDefaults.standard.set(found.localIdentifier, forKey: albumKey)
            return found
        }
        var createdID: String?
        try? PHPhotoLibrary.shared().performChangesAndWait {
            createdID = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                .placeholderForCreatedAssetCollection.localIdentifier
        }
        guard let createdID,
              let created = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [createdID], options: nil).firstObject
        else { return nil }
        UserDefaults.standard.set(createdID, forKey: albumKey)
        return created
    }
}
