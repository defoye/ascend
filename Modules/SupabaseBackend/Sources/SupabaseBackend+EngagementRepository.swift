import DataInterfaces
import Domain
import Foundation
import Supabase

private struct ConsentParams: Encodable {
    let checkEngagementID: String
    let granted: Bool

    enum CodingKeys: String, CodingKey {
        case checkEngagementID = "check_engagement_id"
        case granted
    }
}

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

    /// Flips this engagement's outcome-verification consent via the
    /// `set_consent` RPC (SQL in `20260716121000_rls_hardening.sql`, LH-4)
    /// rather than a read-modify-write upsert: `auth.uid()` is authoritative
    /// server-side for who may grant/revoke consent (only the client, never
    /// the professional -- the RPC raises `consent_client_only` otherwise),
    /// and the RPC sidesteps the RLS upsert-on-conflict INSERT-policy check
    /// that a client-initiated upsert would otherwise fail (see the
    /// migration's Hole 3 comment).
    public func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        do {
            try await client.rpc(
                "set_consent",
                params: ConsentParams(checkEngagementID: engagementID.rawValue, granted: granted)
            ).execute()
        } catch {
            throw Self.mapConsentRPCError(error)
        }
    }

    public func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        guard let row = try await engagementsTable.fetchOne(id: engagementID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
        return row.photoConsentGranted
    }

    /// Flips this engagement's photo-sharing consent via the
    /// `set_photo_consent` RPC — see `setConsent`'s doc comment for why this
    /// isn't a read-modify-write upsert.
    public func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        do {
            try await client.rpc(
                "set_photo_consent",
                params: ConsentParams(checkEngagementID: engagementID.rawValue, granted: granted)
            ).execute()
        } catch {
            throw Self.mapConsentRPCError(error)
        }
    }

    // MARK: - Helpers

    private static func mapConsentRPCError(_ error: Error) -> Error {
        guard let postgrestError = error as? PostgrestError else { return error }
        switch postgrestError.message {
        case "not_found": return SupabaseBackendError.notFound
        default: return error
        }
    }

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
