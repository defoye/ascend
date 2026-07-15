import Domain
import Foundation

/// Row for the `engagements` table. Outcome-derivation consent and photo
/// consent (see `EngagementRepository.consent`/`photoConsent`) live as
/// columns here rather than a separate table — each is a single boolean grant
/// per engagement, the same shape `InMemoryBackend` keeps as a dictionary.
struct EngagementRow: SupabaseRow {
    let id: Identifier<Engagement>
    let clientID: Identifier<Person>
    let professionalID: Identifier<Person>
    let status: EngagementStatus
    let startedAt: Date?
    let endedAt: Date?
    let consentGranted: Bool
    let photoConsentGranted: Bool

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case professionalID = "professional_id"
        case status
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case consentGranted = "consent_granted"
        case photoConsentGranted = "photo_consent_granted"
    }

    init(domain: Engagement, consentGranted: Bool, photoConsentGranted: Bool) {
        id = domain.id
        clientID = domain.clientID
        professionalID = domain.professionalID
        status = domain.status
        startedAt = domain.startedAt
        endedAt = domain.endedAt
        self.consentGranted = consentGranted
        self.photoConsentGranted = photoConsentGranted
    }

    var toDomain: Engagement {
        Engagement(
            id: id,
            clientID: clientID,
            professionalID: professionalID,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }
}
