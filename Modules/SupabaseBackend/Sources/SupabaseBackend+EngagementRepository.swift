import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: EngagementRepository {
    public func get(_ id: Identifier<Engagement>) async throws -> Engagement? {
        try await engagementsTable.fetchOne(id: id.rawValue)?.toDomain
    }

    public func upsert(_ engagement: Engagement) async throws -> Engagement {
        // Preserve existing consent grants across a plain status/date edit —
        // `Engagement` itself carries no consent fields (see `EngagementRow`'s
        // doc comment), so a caller updating only e.g. `status` must not
        // silently reset consent to false.
        let existing = try await engagementsTable.fetchOne(id: engagement.id.rawValue)
        let row = EngagementRow(
            domain: engagement,
            consentGranted: existing?.consentGranted ?? false,
            photoConsentGranted: existing?.photoConsentGranted ?? false
        )
        try await engagementsTable.upsert(row)
        return engagement
    }

    public func delete(_ id: Identifier<Engagement>) async throws {
        try await engagementsTable.delete(id: id.rawValue)
    }

    public func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        try await engagementsList(forProfessional: professionalID)
    }

    public func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        pollingStream { try await self.engagementsList(forProfessional: professionalID) }
    }

    public func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] {
        let rows = try await engagementsTable.fetchAll { $0.eq("client_id", value: clientID.rawValue) }
        return rows.map(\.toDomain).sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
        }
    }

    public func consent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        guard let row = try await engagementsTable.fetchOne(id: engagementID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
        return row.consentGranted
    }

    public func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        guard let row = try await engagementsTable.fetchOne(id: engagementID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
        try await engagementsTable.upsert(
            EngagementRow(domain: row.toDomain, consentGranted: granted, photoConsentGranted: row.photoConsentGranted)
        )
    }

    public func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        guard let row = try await engagementsTable.fetchOne(id: engagementID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
        return row.photoConsentGranted
    }

    public func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        guard let row = try await engagementsTable.fetchOne(id: engagementID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
        try await engagementsTable.upsert(
            EngagementRow(domain: row.toDomain, consentGranted: row.consentGranted, photoConsentGranted: granted)
        )
    }

    // MARK: - Helpers

    private func engagementsList(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        let rows = try await engagementsTable.fetchAll { $0.eq("professional_id", value: professionalID.rawValue) }
        return rows.map(\.toDomain).sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
        }
    }

    var engagementsTable: SupabaseTable<EngagementRow> {
        SupabaseTable(client: client, queue: queue, table: "engagements")
    }
}
