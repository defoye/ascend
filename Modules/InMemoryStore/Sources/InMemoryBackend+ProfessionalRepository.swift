import DataInterfaces
import Domain

extension InMemoryBackend: ProfessionalRepository {
    public func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? {
        professionalProfilesByID[id]
    }

    public func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? {
        professionalProfilesByID.values.first { $0.personID == personID }
    }

    public func listProfiles() async throws -> [ProfessionalProfile] {
        Array(professionalProfilesByID.values).sorted { $0.displayName < $1.displayName }
    }

    public func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile {
        professionalProfilesByID[profile.id] = profile
        return profile
    }

    public func delete(_ id: Identifier<ProfessionalProfile>) async throws {
        guard professionalProfilesByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }
}
