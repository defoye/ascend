import DataInterfaces
import Domain
import Foundation
import Supabase

extension SupabaseBackend: ProgressPhotoRepository {
    /// The private Storage bucket progress-photo objects live in. Bucket-level
    /// and object-level access is RLS/policy-gated server-side (see
    /// `Server/supabase/migrations`) — the client never gets a durable public
    /// URL, only a short-lived signed one per read.
    static let progressPhotoBucket = "progress-photos"

    /// How long a signed URL stays valid. Short enough to limit exposure if a
    /// URL leaks (e.g. via a screenshot or shared log), long enough to cover
    /// one screen's worth of viewing without re-signing mid-scroll.
    static let signedURLExpirySeconds = 300

    public func get(_ id: Identifier<ProgressPhoto>) async throws -> ProgressPhoto? {
        guard let row = try await photosTable.fetchOne(id: id.rawValue) else { return nil }
        return try await resolve(row)
    }

    public func upsert(_ photo: ProgressPhoto) async throws -> ProgressPhoto {
        try await photosTable.upsert(ProgressPhotoRow(domain: photo))
        return photo
    }

    public func delete(_ id: Identifier<ProgressPhoto>) async throws {
        try await photosTable.delete(id: id.rawValue)
    }

    public func fetchPhotos(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto] {
        try await photosList(forEngagement: engagementID)
    }

    public func photos(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressPhoto]> {
        pollingStream { try await self.photosList(forEngagement: engagementID) }
    }

    // MARK: - Helpers

    private func photosList(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto] {
        let rows = try await photosTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        var photos: [ProgressPhoto] = []
        photos.reserveCapacity(rows.count)
        for row in rows.sorted(by: { $0.capturedAt < $1.capturedAt }) {
            photos.append(try await resolve(row))
        }
        return photos
    }

    /// Resolves a stored object key into a fresh signed URL. Falls back to
    /// the raw stored key (rather than throwing) if signing fails — a
    /// dangling/never-uploaded reference shouldn't take down the whole
    /// engagement's photo list; the UI's placeholder-image handling already
    /// tolerates an unloadable reference.
    private func resolve(_ row: ProgressPhotoRow) async throws -> ProgressPhoto {
        let reference: String
        if let signedURL = try? await client.storage.from(Self.progressPhotoBucket).createSignedURL(
            path: row.storagePath,
            expiresIn: Self.signedURLExpirySeconds
        ) {
            reference = signedURL.absoluteString
        } else {
            reference = row.storagePath
        }
        return row.toDomain(reference: reference)
    }

    var photosTable: SupabaseTable<ProgressPhotoRow> {
        SupabaseTable(client: client, queue: queue, table: "progress_photos")
    }
}
