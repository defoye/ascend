import Foundation
import Supabase

/// A generic single-row CRUD gateway for one Postgres table, backing most
/// `SupabaseBackend+*Repository.swift` conformances.
///
/// Every mutation attempts the real network write first; only a transient
/// failure (offline, timeout — see `isTransientFailure`) falls back to
/// `OfflineWriteQueue`, per docs/BACKEND.md's offline-write-queue contract. A
/// real server rejection (RLS denial, constraint violation, ...) is never
/// queued — it's rethrown to the caller immediately.
///
/// Every read opportunistically drains this table's queue first (so a client
/// that's back online converges promptly), then overlays any writes that are
/// still stuck offline on top of the server's rows, so the UI never "reverts"
/// a change the user just made while offline.
struct SupabaseTable<Row: SupabaseRow> {
    let client: SupabaseClient
    let queue: OfflineWriteQueue
    let table: String

    @discardableResult
    func upsert(_ row: Row) async throws -> Row {
        do {
            try await client.from(table).upsert(row, onConflict: "id").execute()
        } catch {
            guard Self.isTransientFailure(error) else { throw error }
            let payload = try SupabaseBackend.jsonEncoder.encode(row)
            await queue.enqueue(table: table, rowID: row.rowID, operation: .upsert, payload: payload)
        }
        return row
    }

    func delete(id: String) async throws {
        do {
            try await client.from(table).delete().eq("id", value: id).execute()
        } catch {
            guard Self.isTransientFailure(error) else { throw error }
            await queue.enqueue(table: table, rowID: id, operation: .delete, payload: nil)
        }
    }

    /// Deletes every row where `column == value`, bypassing the offline
    /// queue — used only to replace a multi-row child collection wholesale as
    /// part of a larger aggregate write (e.g. a `Program`'s weeks, a
    /// `ProfessionalProfile`'s services), which this module deliberately
    /// keeps as direct, non-queued Postgres calls (see `OfflineWriteQueue`'s
    /// doc comment).
    func deleteWhere(column: String, value: String) async throws {
        try await client.from(table).delete().eq(column, value: value).execute()
    }

    /// Fetches every row matching `query`, drained-and-overlaid against the
    /// offline queue. `query` narrows the `PostgrestFilterBuilder` (e.g. an
    /// `.eq` scoping to a parent id); leave it `{ $0 }` for an unfiltered read.
    func fetchAll(
        _ query: (PostgrestFilterBuilder) -> PostgrestFilterBuilder = { $0 }
    ) async throws -> [Row] {
        await drainPending()
        let rows: [Row] = try await query(client.from(table).select()).execute().value
        return await overlayPending(rows)
    }

    func fetchOne(id: String) async throws -> Row? {
        try await fetchAll { $0.eq("id", value: id) }.first
    }

    /// Best-effort: replays this table's queued entries against Postgres.
    /// Entries that still fail transiently stay queued for the next attempt;
    /// entries the server now actively rejects are dropped (there is no
    /// synchronous caller left to hand that rejection back to — see
    /// docs/BACKEND.md's offline-write-queue contract note on this tradeoff).
    func drainPending() async {
        await queue.drain(table: table) { entry in
            switch entry.operation {
            case .upsert:
                guard let payload = entry.payload else { return }
                let row = try SupabaseBackend.jsonDecoder.decode(Row.self, from: payload)
                try await client.from(table).upsert(row, onConflict: "id").execute()
            case .delete:
                try await client.from(table).delete().eq("id", value: entry.rowID).execute()
            }
        }
    }

    private func overlayPending(_ rows: [Row]) async -> [Row] {
        let pendingEntries = await queue.pending(table: table)
        guard !pendingEntries.isEmpty else { return rows }

        var byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.rowID, $0) })
        for entry in pendingEntries {
            switch entry.operation {
            case .upsert:
                if let payload = entry.payload, let row = try? SupabaseBackend.jsonDecoder.decode(Row.self, from: payload) {
                    byID[row.rowID] = row
                }
            case .delete:
                byID.removeValue(forKey: entry.rowID)
            }
        }
        return Array(byID.values)
    }

    /// Whether `error` looks like a connectivity/transient failure (offline,
    /// timed out, connection dropped mid-request) as opposed to the server
    /// actively rejecting the request (bad request, RLS denial, constraint
    /// violation — all of which come back as a well-formed HTTP error
    /// response, not a `URLError`).
    static func isTransientFailure(_ error: Error) -> Bool {
        (error as NSError).domain == NSURLErrorDomain
    }
}
