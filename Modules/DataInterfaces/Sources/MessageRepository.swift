import Domain

/// Messaging is stream-first from the start (see docs/ARCHITECTURE.md): the only
/// read is a live, fully-ordered thread per engagement, never a one-shot page.
public protocol MessageRepository: Sendable {
    /// Live view of an engagement's message thread: emits the current, ordered
    /// snapshot immediately upon subscription, then again whenever a message is
    /// sent.
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]>

    func send(_ message: Message) async throws
}
