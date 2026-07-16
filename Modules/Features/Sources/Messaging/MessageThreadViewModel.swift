import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for a single engagement's message thread: a live-updating,
/// fully-ordered list of `Message`s bound to
/// `MessageRepository.messages(in:)`, a windowed pagination view over that
/// list, and a compose/send flow. Sending goes through
/// `MessageRepository.send(_:)` and the sent message reappears via the live
/// subscription — never applied optimistically — so this view model proves
/// realtime backends are an adapter-only swap later (see
/// docs/ARCHITECTURE.md).
///
/// Depends only on `any Backend`. Mirrors `ProgressViewModel`'s
/// one-shot-then-subscribe idiom.
@MainActor
@Observable
public final class MessageThreadViewModel {
    /// Number of most-recent messages shown per "window"; `loadEarlier()`
    /// grows the window by this amount.
    private static let pageSize = 30

    public private(set) var messages: [Message] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?
    public private(set) var sendErrorMessage: String?

    /// Bound to the compose bar.
    public var draft = ""

    public let backend: any Backend
    public let engagementID: Identifier<Engagement>
    public let selfID: Identifier<Person>

    private var windowSize = MessageThreadViewModel.pageSize

    // `nonisolated(unsafe)`: see `ProgressViewModel` — `Task` is `Sendable`
    // and `cancel()` is thread-safe, which is the only thing `deinit`
    // (necessarily `nonisolated` on a class) needs to do with this — every
    // other access happens from this MainActor-isolated type's own isolated
    // methods.
    nonisolated(unsafe) private var messagesTask: Task<Void, Never>?

    public init(backend: any Backend, engagementID: Identifier<Engagement>, selfID: Identifier<Person>) {
        self.backend = backend
        self.engagementID = engagementID
        self.selfID = selfID
    }

    deinit {
        messagesTask?.cancel()
    }

    /// The most recent `windowSize` messages, oldest first. Basic pagination
    /// over the stream's full ordered snapshot — messaging is stream-first
    /// (see `MessageRepository`), so there's no server-side page to
    /// request; this simply windows the client-held snapshot.
    public var visibleMessages: [Message] {
        Array(messages.suffix(windowSize))
    }

    /// Whether messages older than `visibleMessages` exist.
    public var hasEarlierMessages: Bool {
        messages.count > windowSize
    }

    /// Grows the visible window to reveal older messages.
    public func loadEarlier() {
        windowSize += Self.pageSize
    }

    public func isFromMe(_ message: Message) -> Bool {
        message.authorID == selfID
    }

    /// Loads a one-shot ordered snapshot of the thread so `messages` is
    /// populated the instant `load()` returns, then (re)starts the live
    /// subscription that keeps it current afterwards — started even on
    /// failure, so a later Realtime event or pull-to-refresh retry can still
    /// recover the thread.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await backend.messages.fetchMessages(forEngagement: engagementID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load this conversation. Pull to refresh to try again."
        }

        subscribeToMessages()
    }

    /// Sends `draft` (trimmed) as a new `Message`; a no-op for an empty or
    /// whitespace-only draft. Clears `draft` on success. The sent message
    /// appears in `messages` via the live subscription, not optimistically —
    /// proving the thread is genuinely stream-driven.
    public func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = Message(
            id: Identifier(),
            engagementID: engagementID,
            authorID: selfID,
            body: trimmed,
            sentAt: Date()
        )
        do {
            try await backend.messages.send(message)
            draft = ""
            sendErrorMessage = nil
        } catch {
            sendErrorMessage = "Couldn't send that message. Try again."
        }
    }

    // MARK: - Subscriptions

    private func subscribeToMessages() {
        messagesTask?.cancel()
        messagesTask = Task {
            for await messages in backend.messages.messages(in: engagementID) {
                self.messages = messages
            }
        }
    }
}
