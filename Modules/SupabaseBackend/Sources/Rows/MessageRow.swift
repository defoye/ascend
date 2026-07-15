import Domain
import Foundation

struct MessageRow: SupabaseRow {
    let id: Identifier<Message>
    let engagementID: Identifier<Engagement>
    let authorID: Identifier<Person>
    let body: String
    let sentAt: Date

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case authorID = "author_id"
        case body
        case sentAt = "sent_at"
    }

    init(domain: Message) {
        id = domain.id
        engagementID = domain.engagementID
        authorID = domain.authorID
        body = domain.body
        sentAt = domain.sentAt
    }

    var toDomain: Message {
        Message(id: id, engagementID: engagementID, authorID: authorID, body: body, sentAt: sentAt)
    }
}
