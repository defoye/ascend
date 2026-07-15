import Foundation

/// A durable, ordered, on-device queue of not-yet-synced single-row Postgres
/// writes, keyed by `(table, rowID)` — the offline-write-queue contract
/// documented in docs/BACKEND.md:
///
/// - Writes made while offline (or while a request fails transiently) are
///   appended to a durable, ordered, on-device queue keyed by entity id.
/// - The queue is drained in order as connectivity returns; a write for an
///   entity is never reordered ahead of an earlier write for the same entity.
/// - Repository reads reflect queued, not-yet-synced local writes
///   optimistically, so the UI never "reverts" a change the user just made.
///
/// `SupabaseTable` (the generic single-row CRUD gateway every simple
/// repository is built on) is this queue's only client: it attempts a write
/// directly first, and only falls back to queueing when the failure looks
/// transient (offline/timeout — see `SupabaseTable.isTransientFailure`). A
/// write the server actively rejects (e.g. an RLS policy violation, a
/// constraint failure) is never queued — it's surfaced back to the caller
/// immediately, per the contract's "failed writes ... surface back through
/// the repository's error channel rather than being silently dropped."
///
/// Multi-table aggregate writes (`ProfessionalProfile`'s services/
/// verifications, `Program`'s weeks/workouts/exercises) are not queued here —
/// they replace their child rows transactionally as a batch of direct
/// Postgres calls (see `SupabaseBackend+ProfessionalRepository.swift`,
/// `SupabaseBackend+ProgramRepository.swift`), since a partial offline replay
/// of a multi-statement aggregate write has no safe single-row semantics.
public actor OfflineWriteQueue {
    public enum Operation: String, Codable, Sendable {
        case upsert
        case delete
    }

    public struct Entry: Codable, Sendable, Identifiable {
        public let id: UUID
        public let table: String
        public let rowID: String
        public let operation: Operation
        /// JSON-encoded row for `.upsert`; `nil` for `.delete`.
        public let payload: Data?
        public let queuedAt: Date
    }

    private var entries: [Entry] = []
    private let storeURL: URL?

    /// - Parameter storeURL: Where the queue persists across launches.
    ///   `nil` (e.g. in a sandboxed test environment with no writable
    ///   Application Support directory) degrades gracefully to an in-memory-only
    ///   queue — writes still succeed-or-queue within the process lifetime,
    ///   they just don't survive a relaunch.
    public init(storeURL: URL? = OfflineWriteQueue.defaultStoreURL()) {
        self.storeURL = storeURL
        entries = Self.loadFromDisk(storeURL)
    }

    public static func defaultStoreURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent("SupabaseBackend", isDirectory: true)
            .appendingPathComponent("offline-write-queue.json")
    }

    private static func loadFromDisk(_ url: URL?) -> [Entry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func persist() {
        guard let storeURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Best-effort persistence: the in-memory queue still functions for
            // the rest of this process lifetime even if disk I/O fails.
        }
    }

    /// Appends a pending write. Entries are stored append-only, so draining
    /// front-to-back naturally preserves both overall and per-row order.
    public func enqueue(table: String, rowID: String, operation: Operation, payload: Data?) {
        entries.append(Entry(id: UUID(), table: table, rowID: rowID, operation: operation, payload: payload, queuedAt: Date()))
        persist()
    }

    /// Every pending entry for `table`, oldest first — used to overlay
    /// unsynced local writes on top of a server read.
    public func pending(table: String) -> [Entry] {
        entries.filter { $0.table == table }
    }

    /// Total pending entries across every table, for diagnostics/tests.
    public var count: Int {
        entries.count
    }

    /// Drains only `table`'s entries, in original order. `attempt` performs the
    /// actual network write for one entry; a successful attempt removes that
    /// entry. A failing attempt leaves it queued and "blocks" — skips, without
    /// discarding — every later entry for that same `rowID`, so a row's writes
    /// never get reordered even though independent rows in the same table keep
    /// draining. Entries for other tables are left untouched.
    public func drain(table: String, attempt: (Entry) async throws -> Void) async {
        let ours = entries.filter { $0.table == table }
        guard !ours.isEmpty else { return }

        var blockedRowIDs: Set<String> = []
        var survivedIDs: Set<UUID> = []

        for entry in ours {
            if blockedRowIDs.contains(entry.rowID) {
                survivedIDs.insert(entry.id)
                continue
            }
            do {
                try await attempt(entry)
            } catch {
                blockedRowIDs.insert(entry.rowID)
                survivedIDs.insert(entry.id)
            }
        }

        entries.removeAll { $0.table == table && !survivedIDs.contains($0.id) }
        persist()
    }
}
