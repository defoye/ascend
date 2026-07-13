import Foundation

/// A single week within a `Program`, containing an ordered set of workouts.
public struct ProgramWeek: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ProgramWeek>
    public let index: Int
    public let workouts: [Workout]

    public init(
        id: Identifier<ProgramWeek>,
        index: Int,
        workouts: [Workout]
    ) {
        self.id = id
        self.index = index
        self.workouts = workouts
    }
}
