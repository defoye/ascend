import Domain

/// CRUD access to `Session` records, plus a live view scoped to an engagement.
public protocol SessionRepository: Sendable {
    func get(_ id: Identifier<Session>) async throws -> Session?
    func upsert(_ session: Session) async throws -> Session
    func delete(_ id: Identifier<Session>) async throws

    /// One-shot fetch of a engagement's sessions.
    func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session]

    /// Live view of an engagement's sessions: emits the current snapshot
    /// immediately upon subscription, then again on every mutation.
    func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]>
}
