import Foundation

/// The kind of evidence a `Verification` attests to.
public enum VerificationKind: String, Codable, Sendable, Hashable, CaseIterable {
    case identity
    case certification
    case insurance
}
