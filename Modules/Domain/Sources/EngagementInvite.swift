import Foundation

/// A coach-issued invite code for onboarding a new client (see docs/PRODUCT.md).
///
/// Replaces directly creating a `Person` row for a new client: production RLS
/// requires `people.id == auth.uid()`, so a coach can never create another
/// person's account row. Instead the coach creates an `EngagementInvite`, shares
/// its `code` out-of-band, and the client claims it after signing up for their
/// own account — the claim is what creates the `Engagement`, bound to the
/// claimer's real, authenticated `Person`.
public struct EngagementInvite: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<EngagementInvite>
    public let code: String
    public let professionalID: Identifier<Person>
    /// What the coach typed for the client's name when creating the invite.
    /// Display-only — it is never used to create or match a `Person`; the
    /// claiming client's own account is authoritative for their name.
    public let suggestedClientName: String?
    public let createdAt: Date
    public let claimedByPersonID: Identifier<Person>?
    public let claimedAt: Date?
    public let engagementID: Identifier<Engagement>?

    public init(
        id: Identifier<EngagementInvite>,
        code: String,
        professionalID: Identifier<Person>,
        suggestedClientName: String?,
        createdAt: Date,
        claimedByPersonID: Identifier<Person>?,
        claimedAt: Date?,
        engagementID: Identifier<Engagement>?
    ) {
        self.id = id
        self.code = code
        self.professionalID = professionalID
        self.suggestedClientName = suggestedClientName
        self.createdAt = createdAt
        self.claimedByPersonID = claimedByPersonID
        self.claimedAt = claimedAt
        self.engagementID = engagementID
    }

    public var isClaimed: Bool {
        claimedByPersonID != nil
    }

    /// The alphabet a generated code is drawn from: uppercase letters and
    /// digits, minus `I`, `L`, `O`, `0`, `1` — glyphs that are easy to confuse
    /// with one another (or with each other's near-lookalikes) when a coach
    /// reads a code aloud or a client retypes it from a screenshot.
    private static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    /// Generates a fresh 8-character invite code from `codeAlphabet`.
    ///
    /// Uses `SystemRandomNumberGenerator` (cryptographically secure) rather
    /// than a seedable generator — invite codes are effectively bearer tokens
    /// for starting a coaching relationship, so they must not be predictable.
    public static func generateCode() -> String {
        var generator = SystemRandomNumberGenerator()
        let characters = (0..<8).map { _ in
            codeAlphabet[Int.random(in: 0..<codeAlphabet.count, using: &generator)]
        }
        return String(characters)
    }

    /// Normalizes a client-entered code for matching against a stored code:
    /// trims surrounding whitespace and uppercases it. Claim matching must be
    /// case-insensitive and whitespace-tolerant since codes are typically
    /// typed by hand from a shared message.
    public static func normalize(_ rawCode: String) -> String {
        rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
