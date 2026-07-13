import Foundation

/// A single piece of verification evidence (identity, certification, insurance)
/// attached to a `ProfessionalProfile`.
public struct Verification: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Verification>
    public let kind: VerificationKind
    public let status: VerificationStatus
    public let evidenceURL: URL?

    public init(
        id: Identifier<Verification>,
        kind: VerificationKind,
        status: VerificationStatus,
        evidenceURL: URL?
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.evidenceURL = evidenceURL
    }
}
