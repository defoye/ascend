import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: ProgressPhotoRepository {
    public func get(_ id: Identifier<ProgressPhoto>) async throws -> ProgressPhoto? {
        progressPhotosByID[id]
    }

    public func upsert(_ photo: ProgressPhoto) async throws -> ProgressPhoto {
        progressPhotosByID[photo.id] = photo
        progressPhotoRegistry.yield(progressPhotoList(forEngagement: photo.engagementID), for: photo.engagementID)
        return photo
    }

    public func delete(_ id: Identifier<ProgressPhoto>) async throws {
        guard let removed = progressPhotosByID.removeValue(forKey: id) else { throw InMemoryStoreError.notFound }
        progressPhotoRegistry.yield(progressPhotoList(forEngagement: removed.engagementID), for: removed.engagementID)
    }

    public func fetchPhotos(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto] {
        progressPhotoList(forEngagement: engagementID)
    }

    nonisolated public func photos(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressPhoto]> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeProgressPhotoSubscription(engagementID: engagementID, token: token) }
            }
            Task {
                await self.registerProgressPhotoSubscription(engagementID: engagementID, token: token, continuation: continuation)
            }
        }
    }

    // MARK: - Helpers

    func progressPhotoList(forEngagement engagementID: Identifier<Engagement>) -> [ProgressPhoto] {
        progressPhotosByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    func registerProgressPhotoSubscription(
        engagementID: Identifier<Engagement>,
        token: UUID,
        continuation: AsyncStream<[ProgressPhoto]>.Continuation
    ) {
        progressPhotoRegistry.register(
            key: engagementID,
            token: token,
            continuation: continuation,
            currentValue: progressPhotoList(forEngagement: engagementID)
        )
    }

    func removeProgressPhotoSubscription(engagementID: Identifier<Engagement>, token: UUID) {
        progressPhotoRegistry.remove(key: engagementID, token: token)
    }
}
