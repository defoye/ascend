import Foundation

/// A specific prescription of an `Exercise` within a `Workout`: sets, reps, and
/// optional coaching notes.
public struct ExercisePrescription: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ExercisePrescription>
    public let exercise: Exercise
    public let sets: Int
    public let reps: String
    public let notes: String?

    public init(
        id: Identifier<ExercisePrescription>,
        exercise: Exercise,
        sets: Int,
        reps: String,
        notes: String?
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.reps = reps
        self.notes = notes
    }
}
