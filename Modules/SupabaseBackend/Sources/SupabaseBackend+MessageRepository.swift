import DataInterfaces
import Domain
import Foundation
import Supabase

/// Messaging is built stream-first from the start (see docs/ARCHITECTURE.md):
/// this is the one live view backed by a genuine Supabase Realtime
/// subscription rather than `pollingStream` — a coach/client chat thread is
/// exactly the "wants to feel instantaneous" case Realtime is for. Every
/// other repository's live view (`engagements`, `sessions`, `progress`,
/// `progressPhotos`) polls instead, which is a deliberate, documented choice
/// (see `PollingStream.swift`), not an oversight.
extension SupabaseBackend: MessageRepository {
    public func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Domain.Message]> {
        let client = client
        let fetch: @Sendable () async throws -> [Domain.Message] = {
            let rows: [MessageRow] = try await client.from("messages")
                .select()
                .eq("engagement_id", value: engagement.rawValue)
                .execute()
                .value
            return rows.map(\.toDomain).sorted { $0.sentAt < $1.sentAt }
        }

        return AsyncStream { continuation in
            let task = Task {
                if let initial = try? await fetch() {
                    continuation.yield(initial)
                }

                let channel = client.channel("messages-\(engagement.rawValue)")
                let changes = channel.postgresChange(
                    AnyAction.self,
                    table: "messages",
                    filter: .eq("engagement_id", value: engagement.rawValue)
                )
                await channel.subscribe()

                for await _ in changes {
                    if let updated = try? await fetch() {
                        continuation.yield(updated)
                    }
                }

                await client.removeChannel(channel)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func send(_ message: Domain.Message) async throws {
        // Not queued offline: a message the sender believes was "sent" while
        // actually offline should surface as failed-to-send rather than sit
        // silently in a queue and appear to the other party only much later
        // (unlike a data edit, timing itself is part of a chat message's
        // meaning) — `MessageThreadViewModel`'s existing send-error handling
        // already covers a thrown `send`.
        try await client.from("messages").insert(MessageRow(domain: message)).execute()
    }
}
