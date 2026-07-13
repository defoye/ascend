import Foundation

/// The mode(s) in which a `Person` participates in Ascend. A single person may hold
/// both roles simultaneously (see docs/PRODUCT.md — "One `Person`, with role modes
/// consumer / professional / both").
public enum PersonRole: String, Codable, Sendable, Hashable, CaseIterable {
    case consumer
    case professional
}
