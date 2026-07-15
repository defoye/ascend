import Domain
import Foundation

struct SessionRow: SupabaseRow {
    let id: Identifier<Session>
    let engagementID: Identifier<Engagement>
    let scheduledAt: Date
    let status: SessionStatus

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case scheduledAt = "scheduled_at"
        case status
    }

    init(domain: Session) {
        id = domain.id
        engagementID = domain.engagementID
        scheduledAt = domain.scheduledAt
        status = domain.status
    }

    var toDomain: Session {
        Session(id: id, engagementID: engagementID, scheduledAt: scheduledAt, status: status)
    }
}
