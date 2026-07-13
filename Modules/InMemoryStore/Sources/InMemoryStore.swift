import DataInterfaces
import Domain

/// Namespace for the Ascend InMemoryStore module.
///
/// InMemoryStore is the default backend adapter (DEBUG uses `InMemoryStore.seeded()`)
/// implementing the DataInterfaces protocols with in-memory MockData.
/// See docs/BACKEND.md and docs/TESTING.md.
public enum InMemoryStore {
    /// A backend preloaded with deterministic `MockData` — the default DEBUG
    /// backend (see docs/BACKEND.md). Equivalent to `InMemoryBackend.seeded()`.
    public static func seeded() -> InMemoryBackend {
        InMemoryBackend.seeded()
    }
}
