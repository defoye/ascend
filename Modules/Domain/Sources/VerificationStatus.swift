import Foundation

/// The review status of a `Verification`.
public enum VerificationStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case unverified
    case pending
    case verified
    case rejected
}
