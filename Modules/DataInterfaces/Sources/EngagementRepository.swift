import Domain

/// CRUD access to `Engagement` records, a live view of a professional's client
/// list, and per-engagement client consent.
///
/// Consent lives here rather than on `Engagement` itself: it's a separate,
/// revocable grant (needed by `VerifiedOutcome.derive`), not an intrinsic
/// property of the relationship.
public protocol EngagementRepository: Sendable {
    func get(_ id: Identifier<Engagement>) async throws -> Engagement?
    func upsert(_ engagement: Engagement) async throws -> Engagement
    func delete(_ id: Identifier<Engagement>) async throws

    /// One-shot fetch of a professional's engagements.
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement]

    /// Live view of a professional's engagements: emits the current snapshot
    /// immediately upon subscription, then again on every mutation.
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]>

    /// One-shot fetch of a client's engagements.
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement]

    /// Whether the client has granted consent for outcomes to be derived and
    /// shown for this engagement.
    func consent(for engagementID: Identifier<Engagement>) async throws -> Bool

    /// Grants or revokes consent for this engagement.
    func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws

    /// Whether the client has granted consent for progress **photos** to be
    /// shared with the coach for this engagement.
    ///
    /// Deliberately a separate grant from `consent(for:)` (outcome
    /// derivation): a client may be fine with a coach seeing their numbers
    /// trend over time while never wanting to share photos, or vice versa.
    /// Progress photos MUST NOT be surfaced anywhere unless this is `true`.
    func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool

    /// Grants or revokes photo-sharing consent for this engagement.
    func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws
}
