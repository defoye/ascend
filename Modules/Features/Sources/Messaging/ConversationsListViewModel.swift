import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's per-engagement conversation list: joins every
/// engagement's live message thread with its client's display name into a
/// `ConversationSummary`, live — proving that a realtime backend (Supabase/
/// Firebase) can later replace `InMemoryStore` here purely as an adapter
/// swap (see docs/ARCHITECTURE.md).
///
/// Depends only on `any Backend`. Subscribes to
/// `EngagementRepository.engagements(forProfessional:)` for the engagement
/// roster, then to `MessageRepository.messages(in:)` per engagement for live
/// last-message/unread updates — mirrors `ProgressViewModel`'s
/// one-shot-then-subscribe idiom.
@MainActor
@Observable
public final class ConversationsListViewModel {
    public private(set) var conversations: [ConversationSummary] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    private var clientNames: [Identifier<Engagement>: String] = [:]
    private var messagesByEngagement: [Identifier<Engagement>: [Message]] = [:]

    /// This professional's "last opened" watermark per engagement. Kept only
    /// in memory (no persistence) — set by `markRead(_:)` when a thread is
    /// opened.
    private var lastReadAtByEngagement: [Identifier<Engagement>: Date] = [:]

    // `nonisolated(unsafe)`: `Task` is `Sendable` and `cancel()` is
    // thread-safe, which is the only thing `deinit` (necessarily
    // `nonisolated` on a class) needs to do with these — every other access
    // happens from this MainActor-isolated type's own isolated methods.
    nonisolated(unsafe) private var engagementsTask: Task<Void, Never>?
    nonisolated(unsafe) private var messageTasksByEngagement: [Identifier<Engagement>: Task<Void, Never>] = [:]

    public init(backend: any Backend, professionalID: Identifier<Person>) {
        self.backend = backend
        self.professionalID = professionalID
    }

    deinit {
        engagementsTask?.cancel()
        for task in messageTasksByEngagement.values {
            task.cancel()
        }
    }

    /// Loads a one-shot snapshot of the professional's engagements and each
    /// one's current message thread (so `conversations` is populated the
    /// instant `load()` returns), then (re)starts the live subscriptions
    /// that keep everything current afterwards.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            for engagement in engagements {
                clientNames[engagement.id] = try? await resolveClientName(engagement)
                messagesByEngagement[engagement.id] = await firstSnapshot(of: backend.messages.messages(in: engagement.id))
            }
            rebuildConversations(for: engagements.map(\.id))
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your messages. Pull to refresh to try again."
        }

        subscribeToEngagements()
    }

    /// Marks an engagement's thread read: advances its `lastReadAt`
    /// watermark to the newest message currently known and immediately
    /// recomputes unread count to 0, without waiting on the stream.
    public func markRead(_ engagementID: Identifier<Engagement>) {
        guard let newest = messagesByEngagement[engagementID]?.map(\.sentAt).max() else { return }
        lastReadAtByEngagement[engagementID] = newest
        rebuildConversations(for: [engagementID])
    }

    // MARK: - Subscriptions

    private func subscribeToEngagements() {
        engagementsTask?.cancel()
        engagementsTask = Task {
            for await engagements in backend.engagements.engagements(forProfessional: professionalID) {
                for engagement in engagements where clientNames[engagement.id] == nil {
                    clientNames[engagement.id] = try? await resolveClientName(engagement)
                }
                subscribeToMessages(for: engagements.map(\.id))
            }
        }
    }

    /// Starts a live message subscription for every currently-known
    /// engagement that doesn't already have one, and tears down
    /// subscriptions for engagements no longer in the roster.
    private func subscribeToMessages(for engagementIDs: [Identifier<Engagement>]) {
        let staleIDs = Set(messageTasksByEngagement.keys).subtracting(engagementIDs)
        for id in staleIDs {
            messageTasksByEngagement[id]?.cancel()
            messageTasksByEngagement[id] = nil
            messagesByEngagement[id] = nil
        }

        for engagementID in engagementIDs where messageTasksByEngagement[engagementID] == nil {
            messageTasksByEngagement[engagementID] = Task {
                for await messages in backend.messages.messages(in: engagementID) {
                    self.messagesByEngagement[engagementID] = messages
                    self.rebuildConversations(for: [engagementID])
                }
            }
        }

        conversations = ConversationSummaries.sorted(conversations.filter { engagementIDs.contains($0.engagementID) })
    }

    private func rebuildConversations(for engagementIDs: [Identifier<Engagement>]) {
        for id in engagementIDs {
            let summary = ConversationSummaries.summary(
                engagementID: id,
                clientName: clientNames[id] ?? "Client",
                messages: messagesByEngagement[id] ?? [],
                selfID: professionalID,
                lastReadAt: lastReadAtByEngagement[id]
            )
            if let index = conversations.firstIndex(where: { $0.engagementID == id }) {
                conversations[index] = summary
            } else {
                conversations.append(summary)
            }
        }
        conversations = ConversationSummaries.sorted(conversations)
    }

    private func resolveClientName(_ engagement: Engagement) async throws -> String {
        try await backend.people.get(engagement.clientID)?.displayName ?? "Client"
    }

    /// `messages(in:)` is a live stream, but a one-shot seed only needs the
    /// first emitted value (mirrors `ClientsListViewModel.firstSnapshot`).
    private func firstSnapshot(of stream: AsyncStream<[Message]>) async -> [Message] {
        for await snapshot in stream {
            return snapshot
        }
        return []
    }
}
