import Foundation

/// A single chat message within an `Engagement`.
public struct Message: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Message>
    public let engagementID: Identifier<Engagement>
    public let authorID: Identifier<Person>
    public let body: String
    public let sentAt: Date

    public init(
        id: Identifier<Message>,
        engagementID: Identifier<Engagement>,
        authorID: Identifier<Person>,
        body: String,
        sentAt: Date
    ) {
        self.id = id
        self.engagementID = engagementID
        self.authorID = authorID
        self.body = body
        self.sentAt = sentAt
    }
}
