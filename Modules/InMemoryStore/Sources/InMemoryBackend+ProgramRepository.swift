import DataInterfaces
import Domain

extension InMemoryBackend: ProgramRepository {
    public func get(_ id: Identifier<Program>) async throws -> Program? {
        programsByID[id]
    }

    public func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] {
        programsByID.values.filter { $0.authorID == authorID }.sorted { $0.title < $1.title }
    }

    public func upsert(_ program: Program) async throws -> Program {
        programsByID[program.id] = program
        return program
    }

    public func delete(_ id: Identifier<Program>) async throws {
        guard programsByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }

    public func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment {
        programAssignmentsByID[assignment.id] = assignment
        return assignment
    }

    public func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] {
        programAssignmentsByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.assignedAt < $1.assignedAt }
    }
}
