import Domain
import Foundation

/// Row for the `engagement_invites` table (schema landing in a follow-up
/// migration — see docs/BACKEND.md). `claimed_by`/`claimed_at`/`engagement_id`
/// are all `nil` until `claim_invite` (the Postgres RPC backing
/// `SupabaseBackend.claimInvite`) fills them in server-side.
struct EngagementInviteRow: SupabaseRow {
    let id: Identifier<EngagementInvite>
    let code: String
    let professionalID: Identifier<Person>
    let suggestedClientName: String?
    let createdAt: Date
    let claimedBy: Identifier<Person>?
    let claimedAt: Date?
    let engagementID: Identifier<Engagement>?

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case professionalID = "professional_id"
        case suggestedClientName = "suggested_client_name"
        case createdAt = "created_at"
        case claimedBy = "claimed_by"
        case claimedAt = "claimed_at"
        case engagementID = "engagement_id"
    }

    init(domain: EngagementInvite) {
        id = domain.id
        code = domain.code
        professionalID = domain.professionalID
        suggestedClientName = domain.suggestedClientName
        createdAt = domain.createdAt
        claimedBy = domain.claimedByPersonID
        claimedAt = domain.claimedAt
        engagementID = domain.engagementID
    }

    var toDomain: EngagementInvite {
        EngagementInvite(
            id: id,
            code: code,
            professionalID: professionalID,
            suggestedClientName: suggestedClientName,
            createdAt: createdAt,
            claimedByPersonID: claimedBy,
            claimedAt: claimedAt,
            engagementID: engagementID
        )
    }
}
