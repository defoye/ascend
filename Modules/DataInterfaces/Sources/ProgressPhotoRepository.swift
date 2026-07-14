import Domain

/// CRUD access to `ProgressPhoto` references, plus a live view scoped to an
/// engagement.
///
/// Every read/write here is meaningless unless the caller has separately
/// checked `EngagementRepository.photoConsent(for:)` — this protocol itself
/// has no opinion on consent, exactly like `ProgressRepository` has no
/// opinion on outcome-derivation consent. Features code MUST check
/// `photoConsent` before surfacing anything this repository returns.
public protocol ProgressPhotoRepository: Sendable {
    func get(_ id: Identifier<ProgressPhoto>) async throws -> ProgressPhoto?
    func upsert(_ photo: ProgressPhoto) async throws -> ProgressPhoto
    func delete(_ id: Identifier<ProgressPhoto>) async throws

    /// One-shot fetch of all progress photos for an engagement.
    func fetchPhotos(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto]

    /// Live view of an engagement's progress photos: emits the current
    /// snapshot immediately upon subscription, then again on every mutation.
    func photos(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressPhoto]>
}
