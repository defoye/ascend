import Domain
import Foundation

/// Workout and exercise-prescription lookups/operations, keyed by
/// `weekID`/`workoutID`. Split into its own extension (rather than kept in
/// `ProgramBuilderViewModel`'s primary declaration) purely to stay under
/// SwiftLint's `type_body_length` — SwiftLint measures each type/extension
/// body independently (mirrors the split in `ClientDetailView`).
extension ProgramBuilderViewModel {
    // MARK: - Workout lookups & operations

    public func workout(weekID: Identifier<ProgramWeek>, workoutID: Identifier<Workout>) -> WorkoutDraft? {
        week(withID: weekID)?.workouts.first { $0.id == workoutID }
    }

    public func addWorkout(weekID: Identifier<ProgramWeek>) {
        guard let index = weekIndex(withID: weekID) else { return }
        draft.weeks[index].workouts.append(WorkoutDraft())
    }

    public func setWorkoutName(_ name: String, weekID: Identifier<ProgramWeek>, workoutID: Identifier<Workout>) {
        guard let weekIndex = weekIndex(withID: weekID),
              let workoutIndex = draft.weeks[weekIndex].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        draft.weeks[weekIndex].workouts[workoutIndex].name = name
    }

    public func deleteWorkouts(weekID: Identifier<ProgramWeek>, at offsets: IndexSet) {
        guard let index = weekIndex(withID: weekID) else { return }
        draft.weeks[index].workouts = ProgramDraftOperations.delete(draft.weeks[index].workouts, at: offsets)
    }

    public func moveWorkouts(weekID: Identifier<ProgramWeek>, from source: IndexSet, to destination: Int) {
        guard let index = weekIndex(withID: weekID) else { return }
        draft.weeks[index].workouts = ProgramDraftOperations.move(draft.weeks[index].workouts, from: source, to: destination)
    }

    // MARK: - Exercise prescription operations

    public func addPrescription(_ exercise: Exercise, weekID: Identifier<ProgramWeek>, workoutID: Identifier<Workout>) {
        guard let indices = workoutIndices(weekID: weekID, workoutID: workoutID) else { return }
        draft.weeks[indices.week].workouts[indices.workout].exercises.append(ExercisePrescriptionDraft(exercise: exercise))
    }

    public func updatePrescription(
        _ prescription: ExercisePrescriptionDraft,
        weekID: Identifier<ProgramWeek>,
        workoutID: Identifier<Workout>
    ) {
        guard let indices = workoutIndices(weekID: weekID, workoutID: workoutID),
              let prescriptionIndex = draft.weeks[indices.week].workouts[indices.workout].exercises
                  .firstIndex(where: { $0.id == prescription.id }) else { return }
        draft.weeks[indices.week].workouts[indices.workout].exercises[prescriptionIndex] = prescription
    }

    public func deletePrescriptions(weekID: Identifier<ProgramWeek>, workoutID: Identifier<Workout>, at offsets: IndexSet) {
        guard let indices = workoutIndices(weekID: weekID, workoutID: workoutID) else { return }
        draft.weeks[indices.week].workouts[indices.workout].exercises = ProgramDraftOperations.delete(
            draft.weeks[indices.week].workouts[indices.workout].exercises, at: offsets
        )
    }

    public func movePrescriptions(
        weekID: Identifier<ProgramWeek>,
        workoutID: Identifier<Workout>,
        from source: IndexSet,
        to destination: Int
    ) {
        guard let indices = workoutIndices(weekID: weekID, workoutID: workoutID) else { return }
        draft.weeks[indices.week].workouts[indices.workout].exercises = ProgramDraftOperations.move(
            draft.weeks[indices.week].workouts[indices.workout].exercises, from: source, to: destination
        )
    }

    private func workoutIndices(
        weekID: Identifier<ProgramWeek>,
        workoutID: Identifier<Workout>
    ) -> (week: Int, workout: Int)? {
        guard let weekIndex = weekIndex(withID: weekID),
              let workoutIndex = draft.weeks[weekIndex].workouts.firstIndex(where: { $0.id == workoutID }) else { return nil }
        return (weekIndex, workoutIndex)
    }
}
