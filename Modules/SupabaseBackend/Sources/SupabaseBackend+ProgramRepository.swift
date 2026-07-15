import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: ProgramRepository {
    public func get(_ id: Identifier<Program>) async throws -> Program? {
        guard let row = try await programsTable.fetchOne(id: id.rawValue) else { return nil }
        return try await assemble(row)
    }

    public func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] {
        let rows = try await programsTable.fetchAll { $0.eq("author_id", value: authorID.rawValue) }
        var programs: [Program] = []
        programs.reserveCapacity(rows.count)
        for row in rows {
            programs.append(try await assemble(row))
        }
        return programs.sorted { $0.title < $1.title }
    }

    public func upsert(_ program: Program) async throws -> Program {
        try await programsTable.upsert(ProgramRow(domain: program))
        try await replaceChildren(of: program)
        return program
    }

    public func delete(_ id: Identifier<Program>) async throws {
        try await programsTable.delete(id: id.rawValue)
    }

    public func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment {
        try await assignmentsTable.upsert(ProgramAssignmentRow(domain: assignment))
        return assignment
    }

    public func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] {
        let rows = try await assignmentsTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        return rows.map(\.toDomain).sorted { $0.assignedAt < $1.assignedAt }
    }

    // MARK: - Table accessors

    var programsTable: SupabaseTable<ProgramRow> { SupabaseTable(client: client, queue: queue, table: "programs") }
    var weeksTable: SupabaseTable<ProgramWeekRow> { SupabaseTable(client: client, queue: queue, table: "program_weeks") }
    var workoutsTable: SupabaseTable<WorkoutRow> { SupabaseTable(client: client, queue: queue, table: "workouts") }
    var prescriptionsTable: SupabaseTable<ExercisePrescriptionRow> {
        SupabaseTable(client: client, queue: queue, table: "exercise_prescriptions")
    }
    var exercisesTable: SupabaseTable<ExerciseRow> { SupabaseTable(client: client, queue: queue, table: "exercises") }
    var assignmentsTable: SupabaseTable<ProgramAssignmentRow> {
        SupabaseTable(client: client, queue: queue, table: "program_assignments")
    }
}
