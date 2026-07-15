import Domain
import Foundation

/// Row for the `professional_profiles` table. `services`/`verifications` live
/// in their own tables (see `ServiceRow`/`VerificationRow`), joined in by
/// `SupabaseBackend+ProfessionalRepository`.
struct ProfessionalProfileRow: SupabaseRow {
    let id: Identifier<ProfessionalProfile>
    let personID: Identifier<Person>
    let displayName: String
    let headline: String
    let bio: String

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case personID = "person_id"
        case displayName = "display_name"
        case headline
        case bio
    }

    init(domain: ProfessionalProfile) {
        id = domain.id
        personID = domain.personID
        displayName = domain.displayName
        headline = domain.headline
        bio = domain.bio
    }

    func toDomain(services: [Service], verifications: [Verification]) -> ProfessionalProfile {
        ProfessionalProfile(
            id: id,
            personID: personID,
            displayName: displayName,
            headline: headline,
            bio: bio,
            services: services,
            verifications: verifications
        )
    }
}

struct ServiceRow: SupabaseRow {
    let id: Identifier<Service>
    let professionalProfileID: Identifier<ProfessionalProfile>
    let category: ServiceCategory
    let title: String
    let priceCents: Int
    let currency: String
    let modality: Modality

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case professionalProfileID = "professional_profile_id"
        case category
        case title
        case priceCents = "price_cents"
        case currency
        case modality
    }

    init(professionalProfileID: Identifier<ProfessionalProfile>, domain: Service) {
        id = domain.id
        self.professionalProfileID = professionalProfileID
        category = domain.category
        title = domain.title
        priceCents = domain.priceCents
        currency = domain.currency
        modality = domain.modality
    }

    var toDomain: Service {
        Service(id: id, category: category, title: title, priceCents: priceCents, currency: currency, modality: modality)
    }
}

struct VerificationRow: SupabaseRow {
    let id: Identifier<Verification>
    let professionalProfileID: Identifier<ProfessionalProfile>
    let kind: VerificationKind
    let status: VerificationStatus
    let evidenceURL: URL?

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case professionalProfileID = "professional_profile_id"
        case kind
        case status
        case evidenceURL = "evidence_url"
    }

    init(professionalProfileID: Identifier<ProfessionalProfile>, domain: Verification) {
        id = domain.id
        self.professionalProfileID = professionalProfileID
        kind = domain.kind
        status = domain.status
        evidenceURL = domain.evidenceURL
    }

    var toDomain: Verification {
        Verification(id: id, kind: kind, status: status, evidenceURL: evidenceURL)
    }
}
