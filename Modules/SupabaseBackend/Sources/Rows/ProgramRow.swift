import Domain
import Foundation

/// Row for the `programs` table. The nested `weeks -> workouts ->
/// exercise_prescriptions` tree lives in its own tables (see
/// `ProgramWeekRow`, `WorkoutRow`, `ExercisePrescriptionRow`, `ExerciseRow`),
/// assembled/replaced wholesale by `SupabaseBackend+ProgramRepository`.
struct ProgramRow: SupabaseRow {
    let id: Identifier<Program>
    let authorID: Identifier<Person>
    let title: String
    let summary: String

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case title
        case summary
    }

    init(domain: Program) {
        id = domain.id
        authorID = domain.authorID
        title = domain.title
        summary = domain.summary
    }

    func toDomain(weeks: [ProgramWeek]) -> Program {
        Program(id: id, authorID: authorID, title: title, summary: summary, weeks: weeks)
    }
}

/// Row for the `program_weeks` table.
struct ProgramWeekRow: SupabaseRow {
    let id: Identifier<ProgramWeek>
    let programID: Identifier<Program>
    let index: Int

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case programID = "program_id"
        case index
    }

    init(programID: Identifier<Program>, domain: ProgramWeek) {
        id = domain.id
        self.programID = programID
        index = domain.index
    }

    func toDomain(workouts: [Workout]) -> ProgramWeek {
        ProgramWeek(id: id, index: index, workouts: workouts)
    }
}

/// Row for the `workouts` table. `position` is this workout's 0-based order
/// within its week — `Workout` itself carries no ordering field, so the DB
/// needs an explicit column to preserve the author's ordering across a
/// fetch/re-save round trip.
struct WorkoutRow: SupabaseRow {
    let id: Identifier<Workout>
    let programWeekID: Identifier<ProgramWeek>
    let name: String
    let position: Int

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case programWeekID = "program_week_id"
        case name
        case position
    }

    init(programWeekID: Identifier<ProgramWeek>, position: Int, domain: Workout) {
        id = domain.id
        self.programWeekID = programWeekID
        name = domain.name
        self.position = position
    }

    func toDomain(exercises: [ExercisePrescription]) -> Workout {
        Workout(id: id, name: name, exercises: exercises)
    }
}

/// Row for the `exercise_prescriptions` table; `exerciseID` points at the
/// shared `exercises` library (see `ExerciseRow`).
struct ExercisePrescriptionRow: SupabaseRow {
    let id: Identifier<ExercisePrescription>
    let workoutID: Identifier<Workout>
    let exerciseID: Identifier<Exercise>
    let sets: Int
    let reps: String
    let notes: String?
    let position: Int

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case workoutID = "workout_id"
        case exerciseID = "exercise_id"
        case sets
        case reps
        case notes
        case position
    }

    init(workoutID: Identifier<Workout>, position: Int, domain: ExercisePrescription) {
        id = domain.id
        self.workoutID = workoutID
        exerciseID = domain.exercise.id
        sets = domain.sets
        reps = domain.reps
        notes = domain.notes
        self.position = position
    }

    func toDomain(exercise: Exercise) -> ExercisePrescription {
        ExercisePrescription(id: id, exercise: exercise, sets: sets, reps: reps, notes: notes)
    }
}

/// Row for the shared `exercises` library table.
struct ExerciseRow: SupabaseRow {
    let id: Identifier<Exercise>
    let name: String

    var rowID: String { id.rawValue }

    init(domain: Exercise) {
        id = domain.id
        name = domain.name
    }

    var toDomain: Exercise {
        Exercise(id: id, name: name)
    }
}

/// Row for the `program_assignments` table.
struct ProgramAssignmentRow: SupabaseRow {
    let id: Identifier<ProgramAssignment>
    let programID: Identifier<Program>
    let engagementID: Identifier<Engagement>
    let assignedAt: Date
    let startDate: Date

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case programID = "program_id"
        case engagementID = "engagement_id"
        case assignedAt = "assigned_at"
        case startDate = "start_date"
    }

    init(domain: ProgramAssignment) {
        id = domain.id
        programID = domain.programID
        engagementID = domain.engagementID
        assignedAt = domain.assignedAt
        startDate = domain.startDate
    }

    var toDomain: ProgramAssignment {
        ProgramAssignment(id: id, programID: programID, engagementID: engagementID, assignedAt: assignedAt, startDate: startDate)
    }
}
