import DataInterfaces
import Domain
import Foundation

/// The nested-tree assembly/replacement half of `ProgramRepository`, split
/// into its own file to keep `SupabaseBackend+ProgramRepository.swift`
/// focused on the protocol's public surface (see docs/CONVENTIONS.md file
/// organization / SwiftLint `file_length`).
extension SupabaseBackend {
    /// Reassembles a full `Program` (weeks -> workouts -> exercise
    /// prescriptions, each prescription's `Exercise` resolved from the shared
    /// library) from `row` with a small, fixed number of batched queries —
    /// never one query per nested row.
    func assemble(_ row: ProgramRow) async throws -> Program {
        let weekRows = try await weeksTable.fetchAll { $0.eq("program_id", value: row.id.rawValue) }
        let weekIDs = weekRows.map(\.id.rawValue)
        guard !weekIDs.isEmpty else { return row.toDomain(weeks: []) }

        let workoutRows = try await workoutsTable.fetchAll { $0.`in`("program_week_id", values: weekIDs) }
        let workoutIDs = workoutRows.map(\.id.rawValue)

        let prescriptionRows: [ExercisePrescriptionRow] = workoutIDs.isEmpty
            ? []
            : try await prescriptionsTable.fetchAll { $0.`in`("workout_id", values: workoutIDs) }

        let exerciseIDs = Array(Set(prescriptionRows.map(\.exerciseID.rawValue)))
        let exerciseRows: [ExerciseRow] = exerciseIDs.isEmpty
            ? []
            : try await exercisesTable.fetchAll { $0.`in`("id", values: exerciseIDs) }
        let exercisesByID = Dictionary(uniqueKeysWithValues: exerciseRows.map { ($0.id, $0.toDomain) })

        let prescriptionsByWorkout = Dictionary(grouping: prescriptionRows, by: \.workoutID)
        let workoutsByWeek = Dictionary(grouping: workoutRows, by: \.programWeekID)

        let weeks = weekRows
            .sorted { $0.index < $1.index }
            .map { weekRow -> ProgramWeek in
                let workouts = (workoutsByWeek[weekRow.id] ?? [])
                    .sorted { $0.position < $1.position }
                    .map { workoutRow -> Workout in
                        let exercises = (prescriptionsByWorkout[workoutRow.id] ?? [])
                            .sorted { $0.position < $1.position }
                            .compactMap { prescriptionRow -> ExercisePrescription? in
                                guard let exercise = exercisesByID[prescriptionRow.exerciseID] else { return nil }
                                return prescriptionRow.toDomain(exercise: exercise)
                            }
                        return workoutRow.toDomain(exercises: exercises)
                    }
                return weekRow.toDomain(workouts: workouts)
            }

        return row.toDomain(weeks: weeks)
    }

    /// Replaces `program`'s entire weeks/workouts/prescriptions tree: the
    /// referenced `Exercise` library entries not already present are
    /// inserted first (so foreign keys resolve), the program's existing
    /// weeks are deleted (cascading to their workouts/prescriptions per the
    /// migration's `ON DELETE CASCADE`), then the new tree is bulk-inserted
    /// level by level. `Program` is authored as a whole value (see
    /// `ProgramBuilderViewModel`), exactly like `InMemoryBackend`'s
    /// dictionary-replace `upsert` — this mirrors that "whole value"
    /// semantics for a normalized schema.
    func replaceChildren(of program: Program) async throws {
        let allExercises = program.weeks
            .flatMap(\.workouts)
            .flatMap(\.exercises)
            .map(\.exercise)
        let uniqueExercises = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) }).values
        if !uniqueExercises.isEmpty {
            try await insertMissingExercises(Array(uniqueExercises))
        }

        try await weeksTable.deleteWhere(column: "program_id", value: program.id.rawValue)

        guard !program.weeks.isEmpty else { return }

        let weekRows = program.weeks.map { ProgramWeekRow(programID: program.id, domain: $0) }
        try await client.from("program_weeks").insert(weekRows).execute()

        let workoutRows = program.weeks.flatMap { week in
            week.workouts.enumerated().map { position, workout in
                WorkoutRow(programWeekID: week.id, position: position, domain: workout)
            }
        }
        if !workoutRows.isEmpty {
            try await client.from("workouts").insert(workoutRows).execute()
        }

        let prescriptionRows = program.weeks.flatMap(\.workouts).flatMap { workout in
            workout.exercises.enumerated().map { position, prescription in
                ExercisePrescriptionRow(workoutID: workout.id, position: position, domain: prescription)
            }
        }
        if !prescriptionRows.isEmpty {
            try await client.from("exercise_prescriptions").insert(prescriptionRows).execute()
        }
    }

    /// Inserts only the exercises from `exercises` that don't already exist
    /// in the shared library; never updates an existing row. `exercises` has
    /// no UPDATE policy as of LH-4 (closing a hole that let any
    /// authenticated user rewrite any exercise's name/delete it) -- an
    /// `INSERT ... ON CONFLICT DO UPDATE` against a row with no UPDATE
    /// policy is rejected outright, so this fetches which of `exercises`'
    /// ids already exist and inserts only the rest.
    private func insertMissingExercises(_ exercises: [Exercise]) async throws {
        let ids = exercises.map(\.id.rawValue)
        let existingRows = try await exercisesTable.fetchAll { $0.`in`("id", values: ids) }
        let existingIDs = Set(existingRows.map(\.id))
        let missing = exercises.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return }
        let exerciseRows = missing.map { ExerciseRow(domain: $0) }
        try await client.from("exercises").insert(exerciseRows).execute()
    }
}
