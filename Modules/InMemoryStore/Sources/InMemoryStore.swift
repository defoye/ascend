import DataInterfaces
import Domain

/// Namespace placeholder for the Ascend InMemoryStore module.
///
/// InMemoryStore is the default backend adapter (DEBUG uses `InMemoryStore.seeded()`)
/// implementing the DataInterfaces protocols with in-memory MockData.
/// See docs/BACKEND.md and docs/TESTING.md.
public enum InMemoryStore {}
