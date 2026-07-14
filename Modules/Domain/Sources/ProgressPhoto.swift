import Foundation

/// A reference to a single progress photo captured within an `Engagement`.
///
/// Deliberately holds only a `reference` — a String asset identifier or URL —
/// **never** image bytes. In production this maps to a signed URL into
/// Supabase Storage; `InMemoryStore` treats it as an opaque key. Progress
/// photos are the most sensitive data this app stores, so every read path is
/// gated by the engagement's dedicated photo-sharing consent (see
/// `EngagementRepository.photoConsent(for:)`), separate from the
/// outcome-derivation consent.
public struct ProgressPhoto: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ProgressPhoto>
    public let engagementID: Identifier<Engagement>
    public let reference: String
    public let capturedAt: Date
    public let source: ProgressSource

    public init(
        id: Identifier<ProgressPhoto>,
        engagementID: Identifier<Engagement>,
        reference: String,
        capturedAt: Date,
        source: ProgressSource
    ) {
        self.id = id
        self.engagementID = engagementID
        self.reference = reference
        self.capturedAt = capturedAt
        self.source = source
    }
}
