import Domain

/// CRUD access to `ProfessionalProfile` records, plus the lookup the rest of the
/// app needs most: "the profile for this professional person."
public protocol ProfessionalRepository: Sendable {
    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile?
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile?
    func listProfiles() async throws -> [ProfessionalProfile]
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile
    func delete(_ id: Identifier<ProfessionalProfile>) async throws
}
