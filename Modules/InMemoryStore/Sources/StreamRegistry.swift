import Foundation

/// A trivial, always-equal key used for singleton (unkeyed) live views, such as
/// `AuthGateway.currentAuth`.
struct SingletonKey: Hashable, Sendable {}

/// Fan-out registry for keyed `AsyncStream<Value>` live views.
///
/// This is a plain value type, not an actor — it is only ever touched from
/// within `InMemoryBackend`'s actor-isolated methods, which is what makes
/// mutating it safe under Swift 6 strict concurrency. `register`/`remove` add or
/// drop a subscriber's continuation; `yield` fans a new value out to every
/// subscriber currently registered for a key.
struct StreamRegistry<Key: Hashable & Sendable, Value: Sendable> {
    private var continuationsByKey: [Key: [UUID: AsyncStream<Value>.Continuation]] = [:]

    /// Registers `continuation` under `key`/`token` and immediately yields
    /// `currentValue` to it, so a new subscriber sees the current snapshot
    /// without waiting for the next mutation.
    mutating func register(
        key: Key,
        token: UUID,
        continuation: AsyncStream<Value>.Continuation,
        currentValue: Value
    ) {
        continuation.yield(currentValue)
        continuationsByKey[key, default: [:]][token] = continuation
    }

    /// Drops a previously registered continuation, e.g. when its subscriber's
    /// task is cancelled.
    mutating func remove(key: Key, token: UUID) {
        continuationsByKey[key]?.removeValue(forKey: token)
        if continuationsByKey[key]?.isEmpty == true {
            continuationsByKey.removeValue(forKey: key)
        }
    }

    /// Fans `value` out to every subscriber currently registered for `key`.
    func yield(_ value: Value, for key: Key) {
        continuationsByKey[key]?.values.forEach { $0.yield(value) }
    }
}
