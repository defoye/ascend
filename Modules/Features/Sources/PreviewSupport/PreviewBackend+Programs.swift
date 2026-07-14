import DataInterfaces
import Domain
import Foundation

// MARK: - Program fixtures
//
// Split into their own file (rather than kept in `PreviewBackend.swift`)
// purely to stay under SwiftLint's `file_length` — SwiftLint measures each
// file independently.
extension PreviewBackend {
    static func makePrograms(
        professionalID: Identifier<Person>,
        strengthProgramID: Identifier<Program>
    ) -> [Identifier<Program>: Program] {
        let squat = Exercise(id: Identifier(), name: "Back Squat")
        let bench = Exercise(id: Identifier(), name: "Bench Press")
        let strengthProgram = Program(
            id: strengthProgramID,
            authorID: professionalID,
            title: "Strength Foundations",
            summary: "An 8-week linear progression across the big compound lifts.",
            weeks: [
                ProgramWeek(
                    id: Identifier(),
                    index: 0,
                    workouts: [
                        Workout(
                            id: Identifier(),
                            name: "Lower Body",
                            exercises: [
                                ExercisePrescription(id: Identifier(), exercise: squat, sets: 5, reps: "5", notes: nil)
                            ]
                        )
                    ]
                )
            ]
        )
        let hypertrophyProgram = Program(
            id: Identifier(),
            authorID: professionalID,
            title: "Upper Body Hypertrophy",
            summary: "A 6-week upper-body focused hypertrophy block.",
            weeks: [
                ProgramWeek(
                    id: Identifier(),
                    index: 0,
                    workouts: [
                        Workout(
                            id: Identifier(),
                            name: "Push Day",
                            exercises: [
                                ExercisePrescription(id: Identifier(), exercise: bench, sets: 4, reps: "8-12", notes: nil)
                            ]
                        )
                    ]
                )
            ]
        )
        return [strengthProgram.id: strengthProgram, hypertrophyProgram.id: hypertrophyProgram]
    }

    static func makeAssignments(
        engagementA: Identifier<Engagement>,
        programID: Identifier<Program>,
        now: Date
    ) -> [Identifier<Engagement>: [ProgramAssignment]] {
        [
            engagementA: [
                ProgramAssignment(
                    id: Identifier(),
                    programID: programID,
                    engagementID: engagementA,
                    assignedAt: now.addingTimeInterval(-14 * 86_400),
                    startDate: now.addingTimeInterval(-14 * 86_400)
                )
            ]
        ]
    }
}

struct PreviewProgramRepository: ProgramRepository {
    let programsByID: [Identifier<Program>: Program]
    let assignmentsByEngagement: [Identifier<Engagement>: [ProgramAssignment]]
    func get(_ id: Identifier<Program>) async throws -> Program? { programsByID[id] }
    func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] {
        programsByID.values.filter { $0.authorID == authorID }.sorted { $0.title < $1.title }
    }
    func upsert(_ program: Program) async throws -> Program { program }
    func delete(_ id: Identifier<Program>) async throws {}
    func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment { assignment }
    func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] {
        assignmentsByEngagement[engagementID] ?? []
    }
}
