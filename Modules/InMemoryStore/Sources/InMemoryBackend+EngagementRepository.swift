import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: EngagementRepository {
    public func get(_ id: Identifier<Engagement>) async throws -> Engagement? {
        engagementsByID[id]
    }

    public func upsert(_ engagement: Engagement) async throws -> Engagement {
        engagementsByID[engagement.id] = engagement
        engagementRegistry.yield(engagementsList(forProfessional: engagement.professionalID), for: engagement.professionalID)
        return engagement
    }

    public func delete(_ id: Identifier<Engagement>) async throws {
        guard let removed = engagementsByID.removeValue(forKey: id) else { throw InMemoryStoreError.notFound }
        consentByEngagement.removeValue(forKey: id)
        photoConsentByEngagement.removeValue(forKey: id)
        engagementRegistry.yield(engagementsList(forProfessional: removed.professionalID), for: removed.professionalID)
    }

    public func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        engagementsList(forProfessional: professionalID)
    }

    nonisolated public func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeEngagementSubscription(professionalID: professionalID, token: token) }
            }
            Task {
                await self.registerEngagementSubscription(professionalID: professionalID, token: token, continuation: continuation)
            }
        }
    }

    public func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] {
        engagementsByID.values.filter { $0.clientID == clientID }.sorted { lhs, rhs in
            (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
        }
    }

    public func consent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        guard engagementsByID[engagementID] != nil else { throw InMemoryStoreError.notFound }
        return consentByEngagement[engagementID] ?? false
    }

    public func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        guard engagementsByID[engagementID] != nil else { throw InMemoryStoreError.notFound }
        consentByEngagement[engagementID] = granted
    }

    public func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        guard engagementsByID[engagementID] != nil else { throw InMemoryStoreError.notFound }
        return photoConsentByEngagement[engagementID] ?? false
    }

    public func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        guard engagementsByID[engagementID] != nil else { throw InMemoryStoreError.notFound }
        photoConsentByEngagement[engagementID] = granted
    }

    // MARK: - Helpers

    func engagementsList(forProfessional professionalID: Identifier<Person>) -> [Engagement] {
        engagementsByID.values
            .filter { $0.professionalID == professionalID }
            .sorted { lhs, rhs in (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast) }
    }

    func registerEngagementSubscription(
        professionalID: Identifier<Person>,
        token: UUID,
        continuation: AsyncStream<[Engagement]>.Continuation
    ) {
        engagementRegistry.register(
            key: professionalID,
            token: token,
            continuation: continuation,
            currentValue: engagementsList(forProfessional: professionalID)
        )
    }

    func removeEngagementSubscription(professionalID: Identifier<Person>, token: UUID) {
        engagementRegistry.remove(key: professionalID, token: token)
    }
}
