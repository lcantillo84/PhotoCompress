import Foundation
import ImageIO
import Observation
import PhotosUI
import SwiftUI

/// A picked photo copied to a temp file, so the engine can read it with `CGImageSourceCreateWithURL`.
struct PickedPhoto: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedPhoto(url: destination)
        }
    }
}

struct HarnessReport {
    let result: CompressionResult
    let captureDate: String?
    let cameraModel: String?
    let hasGPS: Bool
}

@MainActor @Observable
final class CompressHarnessModel {
    enum State {
        case idle
        case working
        case done(HarnessReport)
        case failed
    }

    var selection: PhotosPickerItem? {
        didSet { Task { await load() } }
    }
    var targetKB = "500"
    private(set) var state = State.idle
    private(set) var photoURL: URL?

    var canCompress: Bool {
        if case .working = state { return false }
        return photoURL != nil && (Int(targetKB) ?? 0) > 0
    }

    private func load() async {
        removePhoto()
        state = .idle
        guard let selection else { return }
        photoURL = try? await selection.loadTransferable(type: PickedPhoto.self)?.url
        if photoURL == nil { state = .failed }
    }

    func compress() {
        guard let url = photoURL, let kb = Int(targetKB), kb > 0 else { return }
        state = .working
        Task {
            do {
                let report = try await Task.detached(priority: .userInitiated) {
                    let result = try CompressionEngine.compress(sourceURL: url, targetBytes: kb * 1000)
                    return Self.report(for: result)
                }.value
                state = .done(report)
            } catch {
                state = .failed
            }
        }
    }

    private func removePhoto() {
        if let photoURL { try? FileManager.default.removeItem(at: photoURL) }
        photoURL = nil
    }

    nonisolated private static func report(for result: CompressionResult) -> HarnessReport {
        let props = CGImageSourceCreateWithData(result.data as CFData, nil)
            .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }
        let exif = props?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        return HarnessReport(
            result: result,
            captureDate: exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
            cameraModel: tiff?[kCGImagePropertyTIFFModel] as? String,
            hasGPS: props?[kCGImagePropertyGPSDictionary] != nil
        )
    }
}
