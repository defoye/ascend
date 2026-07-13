import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: ProgressRepository {
    public func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry? {
        progressEntriesByID[id]
    }

    public func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry {
        progressEntriesByID[entry.id] = entry
        progressRegistry.yield(progressList(forEngagement: entry.engagementID), for: entry.engagementID)
        return entry
    }

    public func delete(_ id: Identifier<ProgressEntry>) async throws {
        guard let removed = progressEntriesByID.removeValue(forKey: id) else { throw InMemoryStoreError.notFound }
        progressRegistry.yield(progressList(forEngagement: removed.engagementID), for: removed.engagementID)
    }

    public func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] {
        progressList(forEngagement: engagementID)
    }

    public func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry] {
        progressList(forEngagement: engagementID).filter { $0.metric == metric }
    }

    nonisolated public func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeProgressSubscription(engagementID: engagementID, token: token) }
            }
            Task {
                await self.registerProgressSubscription(engagementID: engagementID, token: token, continuation: continuation)
            }
        }
    }

    // MARK: - Helpers

    func progressList(forEngagement engagementID: Identifier<Engagement>) -> [ProgressEntry] {
        progressEntriesByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func registerProgressSubscription(
        engagementID: Identifier<Engagement>,
        token: UUID,
        continuation: AsyncStream<[ProgressEntry]>.Continuation
    ) {
        progressRegistry.register(
            key: engagementID,
            token: token,
            continuation: continuation,
            currentValue: progressList(forEngagement: engagementID)
        )
    }

    func removeProgressSubscription(engagementID: Identifier<Engagement>, token: UUID) {
        progressRegistry.remove(key: engagementID, token: token)
    }
}
