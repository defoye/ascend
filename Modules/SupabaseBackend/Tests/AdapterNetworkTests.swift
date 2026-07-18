import Domain
import Foundation
import Supabase
import Testing
@testable import SupabaseBackend

/// Exercises the adapter's real network paths — the ones previously reachable
/// only by the live-skipping `SupabaseLiveRoundTripTests` — by routing
/// PostgREST through `StubURLProtocol` instead of a live project: the
/// `SupabaseTable` write paths (queue-vs-rethrow, offline-write overlay on
/// reads) and per-repository query construction. Serialized because the
/// stub's handler is process-global (see `StubURLProtocol`).
@Suite("Adapter network paths", .serialized)
struct AdapterNetworkTests {
    private func makeBackend(session: URLSession, queue: OfflineWriteQueue) -> SupabaseBackend {
        SupabaseBackend(
            supabaseURL: URL(string: "https://stub.supabase.co")!,
            supabaseKey: "anon-key",
            session: session,
            queue: queue
        )
    }

    private func makeTable(
        session: URLSession,
        queue: OfflineWriteQueue,
        table: String
    ) -> SupabaseTable<PersonRow> {
        SupabaseTable(client: makeBackend(session: session, queue: queue).client, queue: queue, table: table)
    }

    private func person(_ name: String) -> PersonRow {
        PersonRow(id: Identifier<Person>(), displayName: name, roles: [])
    }

    // MARK: - Write path: queue vs. rethrow

    @Test("upsert against a healthy server succeeds and queues nothing")
    func upsertSuccessQueuesNothing() async throws {
        StubURLProtocol.reset { StubURLProtocol.httpResponse($0, status: 201) }
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")

        _ = try await table.upsert(person("Ada"))

        #expect(await queue.pending(table: "people").isEmpty)
        #expect(!StubURLProtocol.capturedRequests.isEmpty)
    }

    @Test("upsert while offline does not throw and queues the write for replay")
    func upsertOfflineEnqueues() async throws {
        StubURLProtocol.reset { _ in .failure(URLError(.notConnectedToInternet)) }
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")
        let row = person("Grace")

        _ = try await table.upsert(row)

        let pending = await queue.pending(table: "people")
        #expect(pending.count == 1)
        #expect(pending.first?.rowID == row.rowID)
    }

    /// A server rejection (RLS denial, constraint violation) arrives as a 4xx
    /// PostgREST error, not a `URLError` — so it must be rethrown to the
    /// caller and never buried in the retry queue.
    @Test("upsert rejected by the server rethrows and queues nothing")
    func upsertServerRejectionRethrows() async {
        let errorBody = Data(#"{"message":"permission denied for table people","code":"42501"}"#.utf8)
        StubURLProtocol.reset { StubURLProtocol.httpResponse($0, status: 403, body: errorBody) }
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")

        await #expect(throws: (any Error).self) {
            _ = try await table.upsert(person("Mallory"))
        }
        #expect(await queue.pending(table: "people").isEmpty)
    }

    @Test("delete while offline does not throw and queues the delete for replay")
    func deleteOfflineEnqueues() async throws {
        StubURLProtocol.reset { _ in .failure(URLError(.timedOut)) }
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")
        let id = Identifier<Person>().rawValue

        try await table.delete(id: id)

        let pending = await queue.pending(table: "people")
        #expect(pending.count == 1)
        #expect(pending.first?.rowID == id)
    }

    // MARK: - Read path: offline writes overlaid on server rows

    /// The handler serves the read (GET) but fails any write-replay (the drain
    /// that `fetchAll` runs first), so the queued offline write stays queued
    /// and must then be overlaid onto the server's rows.
    private func overlayHandler(serverRows: [PersonRow]) -> StubURLProtocol.Handler {
        let body = (try? SupabaseBackend.jsonEncoder.encode(serverRows)) ?? Data("[]".utf8)
        return { request in
            if request.httpMethod == "GET" {
                return StubURLProtocol.httpResponse(request, status: 200, body: body)
            }
            return .failure(URLError(.notConnectedToInternet))
        }
    }

    @Test("a queued offline upsert is overlaid on top of the server's rows on read")
    func fetchOverlaysQueuedUpsert() async throws {
        let onServer = person("OnServer")
        let offline = person("OfflineOnly")
        StubURLProtocol.reset(overlayHandler(serverRows: [onServer]))
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")
        await queue.enqueue(
            table: "people",
            rowID: offline.rowID,
            operation: .upsert,
            payload: try SupabaseBackend.jsonEncoder.encode(offline)
        )

        let rows = try await table.fetchAll()

        let ids = Set(rows.map(\.rowID))
        #expect(ids == [onServer.rowID, offline.rowID])
    }

    @Test("a queued offline delete removes the row from the read result")
    func fetchOverlaysQueuedDelete() async throws {
        let onServer = person("DoomedRow")
        StubURLProtocol.reset(overlayHandler(serverRows: [onServer]))
        let queue = OfflineWriteQueue(storeURL: nil)
        let table = makeTable(session: StubURLProtocol.makeSession(), queue: queue, table: "people")
        await queue.enqueue(table: "people", rowID: onServer.rowID, operation: .delete, payload: nil)

        let rows = try await table.fetchAll()

        #expect(rows.isEmpty)
    }

    // MARK: - Repository query construction

    /// `pendingInvites` must scope the read to the professional AND to
    /// unclaimed rows; a wrong filter would leak another professional's
    /// invites or surface already-claimed ones. Asserts the outbound PostgREST
    /// query rather than a live result.
    @Test("pendingInvites builds a professional-scoped, unclaimed-only query")
    func pendingInvitesQueryIsScoped() async throws {
        StubURLProtocol.reset { StubURLProtocol.httpResponse($0, status: 200, body: Data("[]".utf8)) }
        let queue = OfflineWriteQueue(storeURL: nil)
        let backend = makeBackend(session: StubURLProtocol.makeSession(), queue: queue)
        let professionalID = Identifier<Person>()

        _ = try await backend.invites.pendingInvites(forProfessional: professionalID)

        let query = try #require(
            StubURLProtocol.capturedRequests
                .compactMap(\.url)
                .first { $0.path.contains("engagement_invites") }?
                .query
        )
        #expect(query.contains("professional_id=eq.\(professionalID.rawValue)"))
        // PostgREST renders a null filter as `is.NULL` (uppercased on the wire).
        #expect(query.contains("claimed_by=is.NULL"))
    }
}
