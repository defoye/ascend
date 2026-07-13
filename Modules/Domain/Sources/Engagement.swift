import Foundation

/// A coaching relationship between a client and a professional.
public struct Engagement: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Engagement>
    public let clientID: Identifier<Person>
    public let professionalID: Identifier<Person>
    public let status: EngagementStatus
    public let startedAt: Date?
    public let endedAt: Date?

    public init(
        id: Identifier<Engagement>,
        clientID: Identifier<Person>,
        professionalID: Identifier<Person>,
        status: EngagementStatus,
        startedAt: Date?,
        endedAt: Date?
    ) {
        self.id = id
        self.clientID = clientID
        self.professionalID = professionalID
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Whether this relationship has actually started: it has a start date and is
    /// no longer merely `.pending`.
    public var isEstablished: Bool {
        startedAt != nil && status != .pending
    }
}
