import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: ProfessionalRepository {
    public func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? {
        guard let row = try await profilesTable.fetchOne(id: id.rawValue) else { return nil }
        return try await assemble(row)
    }

    public func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? {
        let rows = try await profilesTable.fetchAll { $0.eq("person_id", value: personID.rawValue) }
        guard let row = rows.first else { return nil }
        return try await assemble(row)
    }

    public func listProfiles() async throws -> [ProfessionalProfile] {
        let rows = try await profilesTable.fetchAll()
        var profiles: [ProfessionalProfile] = []
        profiles.reserveCapacity(rows.count)
        for row in rows {
            profiles.append(try await assemble(row))
        }
        return profiles
    }

    public func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile {
        try await profilesTable.upsert(ProfessionalProfileRow(domain: profile))

        try await servicesTable.deleteWhere(column: "professional_profile_id", value: profile.id.rawValue)
        if !profile.services.isEmpty {
            let rows = profile.services.map { ServiceRow(professionalProfileID: profile.id, domain: $0) }
            try await client.from("services").insert(rows).execute()
        }

        try await verificationsTable.deleteWhere(column: "professional_profile_id", value: profile.id.rawValue)
        if !profile.verifications.isEmpty {
            let rows = profile.verifications.map { VerificationRow(professionalProfileID: profile.id, domain: $0) }
            try await client.from("verifications").insert(rows).execute()
        }

        return profile
    }

    public func delete(_ id: Identifier<ProfessionalProfile>) async throws {
        try await profilesTable.delete(id: id.rawValue)
    }

    // MARK: - Helpers

    private func assemble(_ row: ProfessionalProfileRow) async throws -> ProfessionalProfile {
        let services = try await servicesTable.fetchAll { $0.eq("professional_profile_id", value: row.id.rawValue) }
        let verifications = try await verificationsTable.fetchAll { $0.eq("professional_profile_id", value: row.id.rawValue) }
        return row.toDomain(services: services.map(\.toDomain), verifications: verifications.map(\.toDomain))
    }

    var profilesTable: SupabaseTable<ProfessionalProfileRow> {
        SupabaseTable(client: client, queue: queue, table: "professional_profiles")
    }

    var servicesTable: SupabaseTable<ServiceRow> {
        SupabaseTable(client: client, queue: queue, table: "services")
    }

    var verificationsTable: SupabaseTable<VerificationRow> {
        SupabaseTable(client: client, queue: queue, table: "verifications")
    }
}
