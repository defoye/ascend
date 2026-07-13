import Foundation

/// A multi-week training program authored by a professional.
public struct Program: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Program>
    public let authorID: Identifier<Person>
    public let title: String
    public let summary: String
    public let weeks: [ProgramWeek]

    public init(
        id: Identifier<Program>,
        authorID: Identifier<Person>,
        title: String,
        summary: String,
        weeks: [ProgramWeek]
    ) {
        self.id = id
        self.authorID = authorID
        self.title = title
        self.summary = summary
        self.weeks = weeks
    }
}
