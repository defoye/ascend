import DataInterfaces
import Domain
import Foundation

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

    /// The fixed instant all seeded `MockData` fixture dates are anchored to
    /// (mirrors `MockData.referenceDate`, ~2023-11-14). Seeded "upcoming"
    /// sessions are a few days after this instant, not after the real
    /// `Date()` — so a composition root that wants the seeded dashboard to
    /// show upcoming sessions should inject this as its clock rather than
    /// `Date()` (see docs/BACKEND.md, docs/TESTING.md).
    public static let referenceDate = MockData.referenceDate

    /// The seeded consumer the demo consumer/client experience (see
    /// docs/ROADMAP.md Prompt 15) runs against — mirrors `MockData.demoClientPersonID`.
    public static let demoClientPersonID = MockData.demoClientPersonID
}
