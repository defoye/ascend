import Foundation

/// A single workout: a named collection of exercise prescriptions.
public struct Workout: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Workout>
    public let name: String
    public let exercises: [ExercisePrescription]

    public init(
        id: Identifier<Workout>,
        name: String,
        exercises: [ExercisePrescription]
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
