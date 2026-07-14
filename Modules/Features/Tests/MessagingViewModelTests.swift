import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

private struct TimeoutError: Error {}

@Suite("Messaging against seeded data")
@MainActor
struct MessageThreadViewModelTests {
    @Test("load() surfaces a seeded engagement's ordered thread")
    func loadsSeededThread() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = MessageThreadViewModel(backend: backend, engagementID: engagement.id, selfID: coach.id)
        await viewModel.load()

        // Client 1 (Morgan Chen / engagement 1) has three seeded messages.
        #expect(viewModel.messages.count == 3)
        #expect(viewModel.messages == viewModel.messages.sorted { $0.sentAt < $1.sentAt })
    }

    @Test("sending a message goes through the repository and appears live in the thread")
    func sendingAppearsLiveInThread() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = MessageThreadViewModel(backend: backend, engagementID: engagement.id, selfID: coach.id)
        await viewModel.load()
        let initialCount = viewModel.messages.count

        let sentBody = "Great session today, keep it up!"
        viewModel.draft = sentBody
        await viewModel.send()

        #expect(viewModel.draft.isEmpty)

        try await waitUntil { viewModel.messages.contains { $0.body == sentBody } }

        #expect(viewModel.messages.count == initialCount + 1)
        let sent = try #require(viewModel.messages.first { $0.body == sentBody })
        #expect(viewModel.isFromMe(sent))
    }

    @Test("send() is a no-op for an empty or whitespace-only draft")
    func sendIgnoresBlankDraft() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = MessageThreadViewModel(backend: backend, engagementID: engagement.id, selfID: coach.id)
        await viewModel.load()
        let initialCount = viewModel.messages.count

        viewModel.draft = "   "
        await viewModel.send()

        #expect(viewModel.messages.count == initialCount)
        #expect(viewModel.draft == "   ")
    }

    @Test("visibleMessages windows the thread and loadEarlier grows the window")
    func paginationWindowsMessages() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = MessageThreadViewModel(backend: backend, engagementID: engagement.id, selfID: coach.id)
        await viewModel.load()

        // Seeded thread (3 messages) is well under the default window, so
        // everything is visible and there's nothing earlier to load.
        #expect(viewModel.visibleMessages.count == viewModel.messages.count)
        #expect(viewModel.hasEarlierMessages == false)

        viewModel.loadEarlier()
        #expect(viewModel.visibleMessages.count == viewModel.messages.count)
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw TimeoutError() }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

@Suite("ConversationSummaries unread logic (pure)")
struct ConversationSummariesTests {
    @Test("counterparty messages after lastReadAt count as unread")
    func counterpartyMessagesAfterLastReadAreUnread() {
        let selfID = Identifier<Person>()
        let otherID = Identifier<Person>()
        let engagementID = Identifier<Engagement>()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)

        let messages = [
            Message(id: Identifier(), engagementID: engagementID, authorID: otherID, body: "before", sentAt: reference),
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: otherID,
                body: "after 1",
                sentAt: reference.addingTimeInterval(60)
            ),
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: otherID,
                body: "after 2",
                sentAt: reference.addingTimeInterval(120)
            )
        ]

        let count = ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: reference)
        #expect(count == 2)
    }

    @Test("a nil lastReadAt means every counterparty message is unread")
    func nilLastReadMeansAllCounterpartyMessagesUnread() {
        let selfID = Identifier<Person>()
        let otherID = Identifier<Person>()
        let engagementID = Identifier<Engagement>()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)

        let messages = [
            Message(id: Identifier(), engagementID: engagementID, authorID: otherID, body: "one", sentAt: reference),
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: otherID,
                body: "two",
                sentAt: reference.addingTimeInterval(60)
            )
        ]

        let count = ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: nil)
        #expect(count == 2)
    }

    @Test("self-authored messages are never unread, regardless of lastReadAt")
    func selfAuthoredMessagesNeverUnread() {
        let selfID = Identifier<Person>()
        let engagementID = Identifier<Engagement>()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)

        let messages = [
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: selfID,
                body: "my message",
                sentAt: reference.addingTimeInterval(3_600)
            )
        ]

        #expect(ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: nil) == 0)
        #expect(ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: reference) == 0)
    }

    @Test("advancing lastReadAt to the newest message date drives unread to 0")
    func advancingLastReadToNewestDrivesUnreadToZero() {
        let selfID = Identifier<Person>()
        let otherID = Identifier<Person>()
        let engagementID = Identifier<Engagement>()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)

        let messages = [
            Message(id: Identifier(), engagementID: engagementID, authorID: otherID, body: "one", sentAt: reference),
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: otherID,
                body: "two",
                sentAt: reference.addingTimeInterval(60)
            )
        ]
        let newest = messages.map(\.sentAt).max()

        #expect(ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: nil) == 2)
        #expect(ConversationSummaries.unreadCount(messages: messages, selfID: selfID, lastReadAt: newest) == 0)
    }

    @Test("summary(...) derives preview/timestamp from the newest message and rolls up unread count")
    func summaryDerivesPreviewAndUnreadCount() {
        let selfID = Identifier<Person>()
        let otherID = Identifier<Person>()
        let engagementID = Identifier<Engagement>()
        let reference = Date(timeIntervalSince1970: 1_700_000_000)

        let messages = [
            Message(id: Identifier(), engagementID: engagementID, authorID: otherID, body: "first", sentAt: reference),
            Message(
                id: Identifier(),
                engagementID: engagementID,
                authorID: selfID,
                body: "latest",
                sentAt: reference.addingTimeInterval(120)
            )
        ]

        let summary = ConversationSummaries.summary(
            engagementID: engagementID,
            clientName: "Morgan Chen",
            messages: messages,
            selfID: selfID,
            lastReadAt: nil
        )

        #expect(summary.lastMessagePreview == "latest")
        #expect(summary.lastMessageAt == reference.addingTimeInterval(120))
        #expect(summary.unreadCount == 1)
    }
}

@Suite("ConversationsListViewModel against seeded data")
@MainActor
struct ConversationsListViewModelTests {
    @Test("load() surfaces a conversation per engagement, sorted by most recent activity")
    func loadSurfacesConversationsSortedByRecency() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })

        let viewModel = ConversationsListViewModel(backend: backend, professionalID: coach.id)
        await viewModel.load()

        #expect(!viewModel.conversations.isEmpty)
        let dates = viewModel.conversations.compactMap(\.lastMessageAt)
        #expect(dates == dates.sorted(by: >))
    }

    @Test("markRead drives a conversation's unread count to 0 without waiting on the stream")
    func markReadDrivesUnreadToZero() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let coach = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = ConversationsListViewModel(backend: backend, professionalID: coach.id)
        await viewModel.load()

        let before = try #require(viewModel.conversations.first { $0.engagementID == engagement.id })
        #expect(before.unreadCount > 0)

        viewModel.markRead(engagement.id)

        let after = try #require(viewModel.conversations.first { $0.engagementID == engagement.id })
        #expect(after.unreadCount == 0)
    }
}
