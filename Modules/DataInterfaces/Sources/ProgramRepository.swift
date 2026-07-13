import Domain

/// CRUD access to `Program` records and assigning them to engagements.
public protocol ProgramRepository: Sendable {
    func get(_ id: Identifier<Program>) async throws -> Program?
    func list(forAuthor authorID: Identifier<Person>) async throws -> [Program]
    func upsert(_ program: Program) async throws -> Program
    func delete(_ id: Identifier<Program>) async throws

    func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment
    func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment]
}
