import Foundation
import Observation
import PhotosUI
import SwiftUI

/// A picked photo copied to a temp file, so the engine can read it with `CGImageSourceCreateWithURL`.
struct PickedPhoto: Transferable {
    let url: URL
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedPhoto(url: destination, name: received.file.deletingPathExtension().lastPathComponent)
        }
    }
}

/// Owns the current batch: importing picked photos, compressing them one at a time, saving each
/// as a new asset, and journaling progress so an interrupted batch can be resumed.
@MainActor @Observable
final class BatchModel {
    enum Phase: Int {
        case home, compose, running, results
    }

    private(set) var phase = Phase.home
    /// Whether the last screen change went deeper into the flow; drives the slide direction.
    private(set) var movedForward = true
    /// True between tapping Cancel and the photo in progress finishing.
    private(set) var isStopping = false
    private(set) var journal: BatchJournal?
    private(set) var importProgress: (done: Int, total: Int)?
    private(set) var currentID: UUID?

    /// nil means the custom size is in use.
    var selectedPreset: Int? = SizePreset.default
    var customAmount: Double?
    var customUnit = SizeUnit.mb
    var keepMetadata = UserDefaults.standard.object(forKey: "keepMetadata") as? Bool ?? true {
        didSet { UserDefaults.standard.set(keepMetadata, forKey: "keepMetadata") }
    }
    var accessDenied = false

    let store: BatchStore
    private var work: Task<Void, Never>?

    init() {
        let support = URL.applicationSupportDirectory
        store = BatchStore(root: support.appendingPathComponent("Batch", isDirectory: true))
        if let saved = BatchJournal.load(from: store.journalURL), saved.canResume {
            journal = saved
        } else {
            store.discard()
        }
    }

    var targetBytes: Int? {
        if let selectedPreset { return selectedPreset }
        guard let customAmount, customAmount > 0 else { return nil }
        let bytes = customAmount * Double(customUnit.rawValue)
        return bytes >= 1_000 ? Int(bytes) : nil
    }

    /// A started batch with photos still to do, offered for resume on the home screen.
    var unfinished: BatchJournal? {
        guard phase == .home, let journal, journal.canResume else { return nil }
        return journal
    }

    // MARK: - Importing

    func add(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty, importProgress == nil else { return }
        importProgress = (0, picked.count)
        let store = store
        work = Task {
            var batch = journal.flatMap { $0.started ? nil : $0 }
                ?? BatchJournal(targetBytes: 0, keepMetadata: true, started: false, items: [])
            if batch.items.isEmpty { store.discard() }
            try? store.prepare()

            for (index, pickerItem) in picked.enumerated() {
                let photo = try? await pickerItem.loadTransferable(type: PickedPhoto.self)
                batch.items.append(await Self.ingest(photo, into: store))
                importProgress = (index + 1, picked.count)
            }
            importProgress = nil
            journal = batch
            persist()
            go(to: .compose)
        }
    }

    nonisolated private static func ingest(_ photo: PickedPhoto?, into store: BatchStore) async -> BatchJournal.Item {
        let id = UUID()
        guard let photo else {
            return .init(id: id, name: "", inboxFile: "", originalBytes: 0, finalBytes: nil, outputFile: nil, status: .failed)
        }
        let file = "\(id.uuidString).\(photo.url.pathExtension)"
        let destination = store.inbox.appendingPathComponent(file)
        do {
            try FileManager.default.moveItem(at: photo.url, to: destination)
        } catch {
            return .init(id: id, name: photo.name, inboxFile: "", originalBytes: 0, finalBytes: nil, outputFile: nil, status: .failed)
        }
        let bytes = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        Thumbnail.write(from: destination, to: store.thumbURL(for: id))
        return .init(id: id, name: photo.name, inboxFile: file, originalBytes: bytes, finalBytes: nil, outputFile: nil, status: .pending)
    }

    // MARK: - Running

    /// Starts the batch from the compose screen with the chosen size and metadata setting.
    func start() {
        guard let targetBytes, journal != nil else { return }
        journal?.targetBytes = targetBytes
        journal?.keepMetadata = keepMetadata
        run()
    }

    func resume() {
        run()
    }

    func retry(_ id: UUID) {
        guard let index = journal?.items.firstIndex(where: { $0.id == id }),
              journal?.items[index].inboxFile.isEmpty == false else { return }
        journal?.items[index].status = .pending
        run()
    }

    private func run() {
        guard let batch = journal else { return }
        let store = store
        let policy: MetadataPolicy = batch.keepMetadata ? .preserveAll : .stripSensitive
        work = Task {
            guard await PhotoSaver.requestAccess() else {
                accessDenied = true
                return
            }
            journal?.started = true
            persist()
            go(to: .running)

            for item in batch.items where item.status == .pending {
                if Task.isCancelled { break }
                currentID = item.id
                let outcome = await Self.process(item, store: store, target: batch.targetBytes, policy: policy)
                apply(outcome, to: item.id)
            }
            currentID = nil
            go(to: journal?.pending.isEmpty == true ? .results : .home)
        }
    }

    private enum Outcome {
        case saved(bytes: Int, file: String)
        case skipped
        case failed
    }

    nonisolated private static func process(
        _ item: BatchJournal.Item, store: BatchStore, target: Int, policy: MetadataPolicy
    ) async -> Outcome {
        guard item.originalBytes > target else { return .skipped }
        do {
            let result = try CompressionEngine.compress(
                sourceURL: store.inbox.appendingPathComponent(item.inboxFile), targetBytes: target, metadata: policy)
            let file = "\(item.name)-\(item.id.uuidString.prefix(8)).jpg"
            let output = store.outbox.appendingPathComponent(file)
            try result.data.write(to: output, options: .atomic)
            try await PhotoSaver.save(fileURL: output)
            return .saved(bytes: result.finalBytes, file: file)
        } catch {
            return .failed
        }
    }

    /// Records the outcome and writes the journal before moving on. The photo is saved to the
    /// library first, so a crash in between can repeat one photo but never lose one.
    private func apply(_ outcome: Outcome, to id: UUID) {
        guard let index = journal?.items.firstIndex(where: { $0.id == id }) else { return }
        switch outcome {
        case .saved(let bytes, let file):
            journal?.items[index].status = .saved
            journal?.items[index].finalBytes = bytes
            journal?.items[index].outputFile = file
        case .skipped:
            journal?.items[index].status = .skipped
        case .failed:
            journal?.items[index].status = .failed
        }
        persist()
        if case .failed = outcome { return }
        if let file = journal?.items[index].inboxFile {
            try? FileManager.default.removeItem(at: store.inbox.appendingPathComponent(file))
        }
    }

    /// Stops after the photo in progress. What's done stays saved; the rest can be resumed.
    func cancel() {
        isStopping = true
        work?.cancel()
    }

    private func go(to next: Phase) {
        movedForward = next.rawValue > phase.rawValue
        isStopping = false
        phase = next
    }

    /// Drops the batch and the app's working copies. Photos already saved to the library stay there.
    func discard() {
        work?.cancel()
        store.discard()
        journal = nil
        importProgress = nil
        currentID = nil
        go(to: .home)
    }

    private func persist() {
        try? journal?.write(to: store.journalURL)
    }

    var sharedFiles: [URL] {
        (journal?.saved ?? []).compactMap { $0.outputFile }.map { store.outbox.appendingPathComponent($0) }
    }

    #if DEBUG
    /// Seeds sample data for screenshots: launch with `-demo compose|running|results|unfinished`.
    func loadDemoIfRequested() {
        guard let name = UserDefaults.standard.string(forKey: "demo") else { return }
        // `-demo e2e -demoFiles /a.heic,/b.jpg` runs the real pipeline on files from disk.
        if name == "e2e", let paths = UserDefaults.standard.string(forKey: "demoFiles") {
            let store = store
            work = Task {
                try? store.prepare()
                var batch = BatchJournal(targetBytes: 500_000, keepMetadata: true, started: false, items: [])
                for path in paths.split(separator: ",") {
                    let source = URL(fileURLWithPath: String(path))
                    let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + source.pathExtension)
                    try? FileManager.default.copyItem(at: source, to: copy)
                    batch.items.append(await Self.ingest(PickedPhoto(url: copy, name: source.deletingPathExtension().lastPathComponent), into: store))
                }
                journal = batch
                run()
            }
            return
        }
        func item(_ name: String, _ bytes: Int, _ status: BatchJournal.Item.Status, _ final: Int? = nil) -> BatchJournal.Item {
            .init(id: UUID(), name: name, inboxFile: "x", originalBytes: bytes, finalBytes: final, outputFile: nil, status: status)
        }
        var items = [
            item("IMG_1713", 3_023_578, .saved, 1_912_004), item("IMG_7608", 4_040_054, .saved, 1_980_274),
            item("IMG_0042", 1_423_870, .skipped), item("IMG_9001", 4_132_180, .failed),
        ]
        items += (0..<36).map { item("IMG_\(8515 + $0)", 2_790_186 + $0 * 40_000, .saved, 1_850_000 + $0 * 3_000) }
        switch name {
        case "compose":
            items = items.map { var copy = $0; copy.status = .pending; copy.finalBytes = nil; return copy }
            journal = BatchJournal(targetBytes: 0, keepMetadata: true, started: false, items: items)
            phase = .compose
        case "running", "unfinished":
            for index in items.indices where index >= 12 || items[index].status != .saved {
                items[index].status = .pending
                items[index].finalBytes = nil
            }
            items.sort { ($0.status == .saved ? 0 : 1) < ($1.status == .saved ? 0 : 1) }
            journal = BatchJournal(targetBytes: 2_000_000, keepMetadata: true, started: true, items: items)
            if name == "running" {
                currentID = journal?.pending.first?.id
                phase = .running
            }
        default:
            journal = BatchJournal(targetBytes: 2_000_000, keepMetadata: true, started: true, items: items)
            phase = .results
        }
    }
    #endif
}
