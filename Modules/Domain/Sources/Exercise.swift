import Foundation

/// A named exercise that can be prescribed within a `Workout`.
public struct Exercise: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Exercise>
    public let name: String

    public init(id: Identifier<Exercise>, name: String) {
        self.id = id
        self.name = name
    }
}
