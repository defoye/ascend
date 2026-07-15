import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: SessionRepository {
    public func get(_ id: Identifier<Session>) async throws -> Session? {
        try await sessionsTable.fetchOne(id: id.rawValue)?.toDomain
    }

    public func upsert(_ session: Session) async throws -> Session {
        try await sessionsTable.upsert(SessionRow(domain: session))
        return session
    }

    public func delete(_ id: Identifier<Session>) async throws {
        try await sessionsTable.delete(id: id.rawValue)
    }

    public func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] {
        try await sessionsList(forEngagement: engagementID)
    }

    public func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        pollingStream { try await self.sessionsList(forEngagement: engagementID) }
    }

    // MARK: - Helpers

    private func sessionsList(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] {
        let rows = try await sessionsTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        return rows.map(\.toDomain).sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var sessionsTable: SupabaseTable<SessionRow> {
        SupabaseTable(client: client, queue: queue, table: "sessions")
    }
}
