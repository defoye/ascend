import Foundation

/// The four evidentiary pillars that must all hold for a `VerifiedOutcome` to be
/// derivable (see docs/PRODUCT.md, Invariant 1).
public struct VerificationBasis: Codable, Sendable, Hashable {
    public let relationshipVerified: Bool
    public let activityVerified: Bool
    public let paymentVerified: Bool
    public let consentGranted: Bool

    public init(
        relationshipVerified: Bool,
        activityVerified: Bool,
        paymentVerified: Bool,
        consentGranted: Bool
    ) {
        self.relationshipVerified = relationshipVerified
        self.activityVerified = activityVerified
        self.paymentVerified = paymentVerified
        self.consentGranted = consentGranted
    }

    /// True iff every pillar holds.
    public var isFullyVerified: Bool {
        relationshipVerified && activityVerified && paymentVerified && consentGranted
    }
}
