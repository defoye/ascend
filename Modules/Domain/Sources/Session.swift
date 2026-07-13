import Foundation

/// A single scheduled coaching session within an `Engagement`.
public struct Session: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Session>
    public let engagementID: Identifier<Engagement>
    public let scheduledAt: Date
    public let status: SessionStatus

    public init(
        id: Identifier<Session>,
        engagementID: Identifier<Engagement>,
        scheduledAt: Date,
        status: SessionStatus
    ) {
        self.id = id
        self.engagementID = engagementID
        self.scheduledAt = scheduledAt
        self.status = status
    }
}
