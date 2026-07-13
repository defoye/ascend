import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: MessageRepository {
    nonisolated public func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeMessageSubscription(engagementID: engagement, token: token) }
            }
            Task {
                await self.registerMessageSubscription(engagementID: engagement, token: token, continuation: continuation)
            }
        }
    }

    public func send(_ message: Message) async throws {
        messagesByID[message.id] = message
        messageRegistry.yield(messagesList(forEngagement: message.engagementID), for: message.engagementID)
    }

    // MARK: - Helpers

    func messagesList(forEngagement engagementID: Identifier<Engagement>) -> [Message] {
        messagesByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.sentAt < $1.sentAt }
    }

    func registerMessageSubscription(
        engagementID: Identifier<Engagement>,
        token: UUID,
        continuation: AsyncStream<[Message]>.Continuation
    ) {
        messageRegistry.register(
            key: engagementID,
            token: token,
            continuation: continuation,
            currentValue: messagesList(forEngagement: engagementID)
        )
    }

    func removeMessageSubscription(engagementID: Identifier<Engagement>, token: UUID) {
        messageRegistry.remove(key: engagementID, token: token)
    }
}
