import Domain
import Foundation

/// Mutable, editable representation of a `Program` used only by the program
/// builder. `Domain` types (`Program`, `ProgramWeek`, `Workout`,
/// `ExercisePrescription`) are immutable value types with memberwise
/// initializers, so the builder works against this parallel mutable tree
/// while the coach edits, and converts to/from the immutable `Domain` types
/// only when loading an existing program or saving (see
/// `ProgramBuilderViewModel`).
///
/// A week's displayed 1-based number is always its position in `weeks`
/// (`index + 1`); `ProgramWeek.index` is (re)assigned from that position when
/// `makeProgram()` builds the immutable value, so weeks stay 0-based
/// contiguous no matter how they were added, duplicated, deleted, or
/// reordered.
public struct ProgramDraft: Identifiable, Equatable {
    public var id: Identifier<Program>
    public var authorID: Identifier<Person>
    public var title: String
    public var summary: String
    public var weeks: [ProgramWeekDraft]

    public init(
        id: Identifier<Program> = Identifier(),
        authorID: Identifier<Person>,
        title: String = "",
        summary: String = "",
        weeks: [ProgramWeekDraft] = []
    ) {
        self.id = id
        self.authorID = authorID
        self.title = title
        self.summary = summary
        self.weeks = weeks
    }

    /// Builds an editable draft from an existing immutable `Program`.
    public init(program: Program) {
        id = program.id
        authorID = program.authorID
        title = program.title
        summary = program.summary
        weeks = program.weeks.sorted { $0.index < $1.index }.map(ProgramWeekDraft.init(week:))
    }

    /// Builds the immutable `Program` this draft represents. Week indices are
    /// assigned from each week's position in `weeks`, so they always come out
    /// 0-based and contiguous.
    public func makeProgram() -> Program {
        Program(
            id: id,
            authorID: authorID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            weeks: weeks.enumerated().map { index, week in week.makeProgramWeek(index: index) }
        )
    }
}

/// A single week within a `ProgramDraft`.
public struct ProgramWeekDraft: Identifiable, Equatable {
    public var id: Identifier<ProgramWeek>
    public var workouts: [WorkoutDraft]

    public init(id: Identifier<ProgramWeek> = Identifier(), workouts: [WorkoutDraft] = []) {
        self.id = id
        self.workouts = workouts
    }

    public init(week: ProgramWeek) {
        id = week.id
        workouts = week.workouts.map(WorkoutDraft.init(workout:))
    }

    public func makeProgramWeek(index: Int) -> ProgramWeek {
        ProgramWeek(id: id, index: index, workouts: workouts.map { $0.makeWorkout() })
    }

    /// A deep copy with fresh identifiers for the week itself, its workouts,
    /// and their exercise prescriptions — backs the builder's "duplicate
    /// week" action.
    public func duplicated() -> ProgramWeekDraft {
        ProgramWeekDraft(id: Identifier(), workouts: workouts.map { $0.duplicated() })
    }
}

/// A single workout within a `ProgramWeekDraft`.
public struct WorkoutDraft: Identifiable, Equatable {
    public var id: Identifier<Workout>
    public var name: String
    public var exercises: [ExercisePrescriptionDraft]

    public init(id: Identifier<Workout> = Identifier(), name: String = "", exercises: [ExercisePrescriptionDraft] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    public init(workout: Workout) {
        id = workout.id
        name = workout.name
        exercises = workout.exercises.map(ExercisePrescriptionDraft.init(prescription:))
    }

    public func makeWorkout() -> Workout {
        Workout(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), exercises: exercises.map { $0.makePrescription() })
    }

    public func duplicated() -> WorkoutDraft {
        WorkoutDraft(id: Identifier(), name: name, exercises: exercises.map { $0.duplicated() })
    }
}

/// A single exercise prescription within a `WorkoutDraft`. `notes` is a plain
/// (non-optional) `String` here for simpler text-field binding; it collapses
/// to `nil` on blank input when converted back to `Domain.ExercisePrescription`.
public struct ExercisePrescriptionDraft: Identifiable, Equatable {
    public var id: Identifier<ExercisePrescription>
    public var exercise: Exercise
    public var sets: Int
    public var reps: String
    public var notes: String

    public init(
        id: Identifier<ExercisePrescription> = Identifier(),
        exercise: Exercise,
        sets: Int = 3,
        reps: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.notes = notes
    }

    public init(prescription: ExercisePrescription) {
        id = prescription.id
        exercise = prescription.exercise
        sets = prescription.sets
        reps = prescription.reps
        notes = prescription.notes ?? ""
    }

    public func makePrescription() -> ExercisePrescription {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExercisePrescription(
            id: id,
            exercise: exercise,
            sets: sets,
            reps: reps.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
    }

    public func duplicated() -> ExercisePrescriptionDraft {
        ExercisePrescriptionDraft(id: Identifier(), exercise: exercise, sets: sets, reps: reps, notes: notes)
    }
}
