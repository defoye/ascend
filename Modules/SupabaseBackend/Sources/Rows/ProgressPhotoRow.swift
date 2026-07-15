import Domain
import Foundation

/// Row for the `progress_photos` table. `storagePath` is the permanent
/// object key within the private `progress-photos` Storage bucket — never
/// image bytes, never a long-lived public URL. `SupabaseBackend+
/// ProgressPhotoRepository` resolves it to a short-lived signed URL on every
/// read and substitutes that into `ProgressPhoto.reference`, matching
/// docs/DATA_MODEL.md: "in production this maps to a signed URL into
/// Supabase Storage."
struct ProgressPhotoRow: SupabaseRow {
    let id: Identifier<ProgressPhoto>
    let engagementID: Identifier<Engagement>
    let storagePath: String
    let capturedAt: Date
    let source: ProgressSource

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case storagePath = "storage_path"
        case capturedAt = "captured_at"
        case source
    }

    /// - Parameter storagePath: The bucket-relative object key. When
    ///   `domain.reference` already looks like a storage path (the shape
    ///   `ProgressPhotoRepository.upsert` callers pass after an upload — see
    ///   `EngagementProgressView+Photos.swift`'s capture flow) it's used
    ///   as-is; a caller that instead hands back a previously-*resolved*
    ///   signed URL (round-tripping a value this repository itself returned)
    ///   would corrupt the stored key, so upload call sites must pass the
    ///   storage key, not a signed URL.
    init(domain: ProgressPhoto) {
        id = domain.id
        engagementID = domain.engagementID
        storagePath = domain.reference
        capturedAt = domain.capturedAt
        source = domain.source
    }

    func toDomain(reference: String) -> ProgressPhoto {
        ProgressPhoto(id: id, engagementID: engagementID, reference: reference, capturedAt: capturedAt, source: source)
    }
}
