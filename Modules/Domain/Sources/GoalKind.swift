import Foundation

/// The kind of goal a `Person` is pursuing.
public enum GoalKind: String, Codable, Sendable, Hashable, CaseIterable {
    case loseWeight
    case buildMuscle
    case getStronger
    case improveMobility
    case recoverFromInjury
    case trainForSport
    case improveEndurance
    case generalHealth
}
