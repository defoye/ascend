import Foundation

/// The assignment of a `Program` to a specific `Engagement`.
public struct ProgramAssignment: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ProgramAssignment>
    public let programID: Identifier<Program>
    public let engagementID: Identifier<Engagement>
    public let assignedAt: Date
    public let startDate: Date

    public init(
        id: Identifier<ProgramAssignment>,
        programID: Identifier<Program>,
        engagementID: Identifier<Engagement>,
        assignedAt: Date,
        startDate: Date
    ) {
        self.id = id
        self.programID = programID
        self.engagementID = engagementID
        self.assignedAt = assignedAt
        self.startDate = startDate
    }
}
