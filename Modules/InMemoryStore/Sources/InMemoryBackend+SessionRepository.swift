import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: SessionRepository {
    public func get(_ id: Identifier<Session>) async throws -> Session? {
        sessionsByID[id]
    }

    public func upsert(_ session: Session) async throws -> Session {
        sessionsByID[session.id] = session
        sessionRegistry.yield(sessionsList(forEngagement: session.engagementID), for: session.engagementID)
        return session
    }

    public func delete(_ id: Identifier<Session>) async throws {
        guard let removed = sessionsByID.removeValue(forKey: id) else { throw InMemoryStoreError.notFound }
        sessionRegistry.yield(sessionsList(forEngagement: removed.engagementID), for: removed.engagementID)
    }

    public func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] {
        sessionsList(forEngagement: engagementID)
    }

    nonisolated public func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeSessionSubscription(engagementID: engagementID, token: token) }
            }
            Task {
                await self.registerSessionSubscription(engagementID: engagementID, token: token, continuation: continuation)
            }
        }
    }

    // MARK: - Helpers

    func sessionsList(forEngagement engagementID: Identifier<Engagement>) -> [Session] {
        sessionsByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    func registerSessionSubscription(
        engagementID: Identifier<Engagement>,
        token: UUID,
        continuation: AsyncStream<[Session]>.Continuation
    ) {
        sessionRegistry.register(
            key: engagementID,
            token: token,
            continuation: continuation,
            currentValue: sessionsList(forEngagement: engagementID)
        )
    }

    func removeSessionSubscription(engagementID: Identifier<Engagement>, token: UUID) {
        sessionRegistry.remove(key: engagementID, token: token)
    }
}
