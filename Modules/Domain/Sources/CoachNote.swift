import Foundation

/// A coach's private note about a client engagement — visible only to the
/// professional who wrote it, not the client.
public struct CoachNote: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<CoachNote>
    public let engagementID: Identifier<Engagement>
    public let authorID: Identifier<Person>
    public let body: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: Identifier<CoachNote>,
        engagementID: Identifier<Engagement>,
        authorID: Identifier<Person>,
        body: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.engagementID = engagementID
        self.authorID = authorID
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
