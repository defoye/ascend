import Domain

/// Messaging pairs a one-shot throwing read with a live view, the same
/// division of labor `SessionRepository` uses for `fetchSessions`/`sessions`:
/// callers that only need a snapshot to populate a screen (or that are
/// aggregating across many engagements, e.g. a dashboard) must use
/// `fetchMessages` — it fails loudly on a network error rather than hanging,
/// unlike `messages(in:)`, whose `AsyncStream` has no throwing channel and
/// simply yields nothing until the next successful fetch. Reach for
/// `messages(in:)` only where a genuine live subscription is being kept (a
/// screen visibly showing a thread).
public protocol MessageRepository: Sendable {
    /// One-shot, ordered (oldest-first by `sentAt`) fetch of an engagement's
    /// message thread. Throws on failure — callers must not await this
    /// forever on partial connectivity.
    func fetchMessages(forEngagement engagementID: Identifier<Engagement>) async throws -> [Message]

    /// Live view of an engagement's message thread: emits the current, ordered
    /// snapshot immediately upon subscription, then again whenever a message is
    /// sent.
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]>

    func send(_ message: Message) async throws
}
