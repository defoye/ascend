import Domain
import Foundation

struct CoachNoteRow: SupabaseRow {
    let id: Identifier<CoachNote>
    let engagementID: Identifier<Engagement>
    let authorID: Identifier<Person>
    let body: String
    let createdAt: Date
    let updatedAt: Date

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case authorID = "author_id"
        case body
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(domain: CoachNote) {
        id = domain.id
        engagementID = domain.engagementID
        authorID = domain.authorID
        body = domain.body
        createdAt = domain.createdAt
        updatedAt = domain.updatedAt
    }

    var toDomain: CoachNote {
        CoachNote(id: id, engagementID: engagementID, authorID: authorID, body: body, createdAt: createdAt, updatedAt: updatedAt)
    }
}
