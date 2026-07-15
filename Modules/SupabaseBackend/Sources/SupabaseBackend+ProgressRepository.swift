import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: ProgressRepository {
    public func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry? {
        try await progressTable.fetchOne(id: id.rawValue)?.toDomain
    }

    public func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry {
        try await progressTable.upsert(ProgressEntryRow(domain: entry))
        return entry
    }

    public func delete(_ id: Identifier<ProgressEntry>) async throws {
        try await progressTable.delete(id: id.rawValue)
    }

    public func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] {
        try await entriesList(forEngagement: engagementID)
    }

    public func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry] {
        try await entriesList(forEngagement: engagementID).filter { $0.metric == metric }
    }

    public func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]> {
        pollingStream { try await self.entriesList(forEngagement: engagementID) }
    }

    // MARK: - Helpers

    private func entriesList(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] {
        let rows = try await progressTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        return rows.map(\.toDomain).sorted { $0.recordedAt < $1.recordedAt }
    }

    var progressTable: SupabaseTable<ProgressEntryRow> {
        SupabaseTable(client: client, queue: queue, table: "progress_entries")
    }
}
