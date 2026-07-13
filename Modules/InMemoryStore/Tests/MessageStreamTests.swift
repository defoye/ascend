import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

private struct StreamTestTimeoutError: Error {}

@Suite("Message stream")
struct MessageStreamTests {
    @Test("messages(in:) emits an updated thread after send")
    func streamEmitsOnSend() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let authorID = Identifier<Person>()
        let message = Message(
            id: Identifier(),
            engagementID: engagementID,
            authorID: authorID,
            body: "Hello there",
            sentAt: Date()
        )

        let received: [Message]? = try await withThrowingTaskGroup(of: [Message]?.self) { group in
            group.addTask {
                for await snapshot in backend.messages.messages(in: engagementID) where snapshot.contains(where: { $0.id == message.id }) {
                    return snapshot
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                throw StreamTestTimeoutError()
            }

            // Give the subscription a moment to register before sending, though
            // the design guarantees correctness even without this: a subscriber
            // always receives the current snapshot immediately upon subscribing.
            try await Task.sleep(nanoseconds: 100_000_000)
            try await backend.messages.send(message)

            guard let first = try await group.next() else { throw StreamTestTimeoutError() }
            group.cancelAll()
            return first
        }

        let messages = try #require(received)
        #expect(messages.map(\.id) == [message.id])
        #expect(messages.first?.body == "Hello there")
    }

    @Test("a new subscriber immediately receives the current snapshot, not just future sends")
    func newSubscriberReceivesCurrentSnapshot() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let authorID = Identifier<Person>()
        let message = Message(
            id: Identifier(),
            engagementID: engagementID,
            authorID: authorID,
            body: "Already here",
            sentAt: Date()
        )
        try await backend.messages.send(message)

        let received: [Message]? = try await withThrowingTaskGroup(of: [Message]?.self) { group in
            group.addTask {
                for await snapshot in backend.messages.messages(in: engagementID) where !snapshot.isEmpty {
                    return snapshot
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                throw StreamTestTimeoutError()
            }

            guard let first = try await group.next() else { throw StreamTestTimeoutError() }
            group.cancelAll()
            return first
        }

        let messages = try #require(received)
        #expect(messages.map(\.id) == [message.id])
    }
}
