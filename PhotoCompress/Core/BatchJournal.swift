import Foundation

/// The record of a batch, rewritten to disk after every photo so a crash or force-quit
/// never loses track of which photos are done.
struct BatchJournal: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Identifiable, Sendable {
        enum Status: String, Codable, Sendable {
            case pending, saved, skipped, failed
        }

        let id: UUID
        var name: String
        /// File name inside the store's inbox; empty if the photo could not be imported.
        var inboxFile: String
        var originalBytes: Int
        var finalBytes: Int?
        /// File name inside the store's outbox, kept so results can be shared.
        var outputFile: String?
        var status: Status
    }

    var targetBytes: Int
    var keepMetadata: Bool
    /// False while the user is still choosing a size; such a batch is not resumed.
    var started: Bool
    var items: [Item]

    var pending: [Item] { items.filter { $0.status == .pending } }
    var doneCount: Int { items.count - pending.count }
    var saved: [Item] { items.filter { $0.status == .saved } }
    var totalOriginalBytes: Int { items.reduce(0) { $0 + $1.originalBytes } }
    var canResume: Bool { started && !pending.isEmpty }

    static func load(from url: URL) -> BatchJournal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BatchJournal.self, from: data)
    }

    func write(to url: URL) throws {
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// On-disk layout for the current batch.
struct BatchStore: Sendable {
    let root: URL

    var journalURL: URL { root.appendingPathComponent("journal.json") }
    var inbox: URL { root.appendingPathComponent("inbox", isDirectory: true) }
    var outbox: URL { root.appendingPathComponent("outbox", isDirectory: true) }
    var thumbs: URL { root.appendingPathComponent("thumbs", isDirectory: true) }

    func thumbURL(for id: UUID) -> URL { thumbs.appendingPathComponent("\(id.uuidString).jpg") }

    func prepare() throws {
        for directory in [inbox, outbox, thumbs] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// Removes every file of the batch. Only touches the app's own copies, never the photo library.
    func discard() {
        try? FileManager.default.removeItem(at: root)
    }
}
