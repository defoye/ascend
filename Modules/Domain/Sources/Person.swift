import Foundation

/// A person using Ascend, either as a consumer, a professional, or both (see
/// docs/PRODUCT.md).
public struct Person: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Person>
    public let displayName: String
    public let roles: Set<PersonRole>
    public let goals: [Goal]

    public init(
        id: Identifier<Person>,
        displayName: String,
        roles: Set<PersonRole>,
        goals: [Goal]
    ) {
        self.id = id
        self.displayName = displayName
        self.roles = roles
        self.goals = goals
    }
}
