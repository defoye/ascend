import Foundation

/// How a `Service` is delivered.
public enum Modality: String, Codable, Sendable, Hashable, CaseIterable {
    case inPerson
    case virtual
    case hybrid
}
