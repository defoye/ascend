import Foundation

/// A live `AsyncStream` backed by periodic re-fetching rather than a Realtime
/// subscription — for repository live views where a full websocket
/// subscription isn't worth the complexity (see docs/ARCHITECTURE.md:
/// "other live `AsyncStream` reads can poll/subscribe as appropriate").
/// `MessageRepository.messages(in:)` is the one live view built on Supabase
/// Realtime instead (`SupabaseBackend+MessageRepository.swift`), matching
/// docs/ARCHITECTURE.md's "messaging is built stream-first from the start."
///
/// Yields the current snapshot immediately, then again every `interval`,
/// silently skipping a tick if `fetch` throws (a transient network hiccup
/// shouldn't tear down the subscriber's stream) so the next tick can recover.
func pollingStream<Value: Sendable>(
    interval: Duration = .seconds(5),
    fetch: @escaping @Sendable () async throws -> Value
) -> AsyncStream<Value> {
    AsyncStream { continuation in
        let task = Task {
            while !Task.isCancelled {
                if let value = try? await fetch() {
                    continuation.yield(value)
                }
                try? await Task.sleep(for: interval)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}
