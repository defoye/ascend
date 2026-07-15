import Foundation
import Testing
@testable import SupabaseBackend

/// Pure, no-network tests of the offline-write-queue contract documented in
/// docs/BACKEND.md and `OfflineWriteQueue`'s own doc comment: ordered,
/// durable-shaped (in-memory here since `storeURL: nil`), and per-row
/// ordering preserved across a partial-failure drain.
@Suite("OfflineWriteQueue")
struct OfflineWriteQueueTests {
    @Test("enqueue then drain with a succeeding attempt empties the queue")
    func drainSuccess() async {
        let queue = OfflineWriteQueue(storeURL: nil)
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: Data("{}".utf8))

        var attempted: [String] = []
        await queue.drain(table: "sessions") { entry in
            attempted.append(entry.rowID)
        }

        #expect(attempted == ["row-1"])
        #expect(await queue.count == 0)
    }

    @Test("a failing attempt leaves its entry queued")
    func drainFailureStaysQueued() async {
        let queue = OfflineWriteQueue(storeURL: nil)
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: Data("{}".utf8))

        struct Boom: Error {}
        await queue.drain(table: "sessions") { _ in throw Boom() }

        #expect(await queue.count == 1)
    }

    @Test("a later write for the same row is never applied ahead of an earlier failed one")
    func perRowOrderingPreserved() async {
        let queue = OfflineWriteQueue(storeURL: nil)
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: Data("{\"n\":1}".utf8))
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: Data("{\"n\":2}".utf8))

        struct Boom: Error {}
        var attemptedPayloads: [Data] = []
        await queue.drain(table: "sessions") { entry in
            attemptedPayloads.append(entry.payload ?? Data())
            throw Boom()
        }

        // Only the FIRST entry for row-1 was attempted — the second stayed
        // blocked behind it rather than racing ahead.
        #expect(attemptedPayloads.count == 1)
        #expect(await queue.count == 2)
    }

    @Test("draining one table never touches another table's entries")
    func drainScopedToTable() async {
        let queue = OfflineWriteQueue(storeURL: nil)
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: nil)
        await queue.enqueue(table: "messages", rowID: "row-2", operation: .upsert, payload: nil)

        await queue.drain(table: "sessions") { _ in }

        #expect(await queue.count == 1)
        #expect(await queue.pending(table: "messages").count == 1)
        #expect(await queue.pending(table: "sessions").isEmpty)
    }

    @Test("independent rows in the same table keep draining after one row blocks")
    func independentRowsUnaffected() async {
        let queue = OfflineWriteQueue(storeURL: nil)
        await queue.enqueue(table: "sessions", rowID: "row-1", operation: .upsert, payload: nil)
        await queue.enqueue(table: "sessions", rowID: "row-2", operation: .upsert, payload: nil)

        struct Boom: Error {}
        var attempted: [String] = []
        await queue.drain(table: "sessions") { entry in
            attempted.append(entry.rowID)
            if entry.rowID == "row-1" { throw Boom() }
        }

        #expect(attempted == ["row-1", "row-2"])
        #expect(await queue.count == 1)
        #expect(await queue.pending(table: "sessions").first?.rowID == "row-1")
    }
}
