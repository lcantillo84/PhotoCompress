import Foundation
import XCTest
@testable import PhotoCompressCore

final class BatchJournalTests: XCTestCase {
    private var store: BatchStore!

    override func setUpWithError() throws {
        store = BatchStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("pc-batch-\(UUID().uuidString)"))
        try store.prepare()
    }

    override func tearDown() {
        store.discard()
    }

    private func item(_ status: BatchJournal.Item.Status) -> BatchJournal.Item {
        .init(id: UUID(), name: "IMG", inboxFile: "a.heic", originalBytes: 3_000_000, finalBytes: nil, outputFile: nil, status: status)
    }

    func testRoundTripsThroughDisk() throws {
        let journal = BatchJournal(targetBytes: 2_000_000, keepMetadata: true, started: true, items: [item(.saved), item(.pending)])
        try journal.write(to: store.journalURL)
        XCTAssertEqual(BatchJournal.load(from: store.journalURL), journal)
    }

    func testResumeOnlyCoversPendingItems() {
        let journal = BatchJournal(
            targetBytes: 500_000, keepMetadata: true, started: true,
            items: [item(.saved), item(.skipped), item(.failed), item(.pending), item(.pending)])
        XCTAssertEqual(journal.pending.count, 2)
        XCTAssertEqual(journal.doneCount, 3)
        XCTAssertTrue(journal.canResume)
    }

    func testFinishedOrUnstartedBatchIsNotResumable() {
        var journal = BatchJournal(targetBytes: 500_000, keepMetadata: true, started: true, items: [item(.saved)])
        XCTAssertFalse(journal.canResume)
        journal = BatchJournal(targetBytes: 500_000, keepMetadata: true, started: false, items: [item(.pending)])
        XCTAssertFalse(journal.canResume)
    }

    func testMissingOrCorruptJournalLoadsAsNil() throws {
        XCTAssertNil(BatchJournal.load(from: store.journalURL))
        try Data("not json".utf8).write(to: store.journalURL)
        XCTAssertNil(BatchJournal.load(from: store.journalURL))
    }

    func testDiscardRemovesEverything() throws {
        try Data([1]).write(to: store.inbox.appendingPathComponent("a.heic"))
        store.discard()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.path))
    }
}
