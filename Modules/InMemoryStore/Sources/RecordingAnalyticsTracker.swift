import DataInterfaces
import Foundation

/// A call-recording `AnalyticsTracking` spy, used as `InMemoryBackend`'s
/// default tracker (mirroring `MockSessionReminderScheduler` — see
/// `Modules/Features/Sources/Schedule`) so previews/tests/the DEBUG demo
/// build never depend on a real analytics SDK, and tests can assert exactly
/// which events fired without any PII ever entering the recorded log (see
/// `AnalyticsTracking.swift`'s no-PII invariant).
///
/// A plain `NSLock`-guarded class rather than an actor: `AnalyticsTracking
/// .track(_:)` is a synchronous, fire-and-forget protocol requirement (no
/// caller should ever have to `await` an analytics call), so recording has
/// to be synchronous too for tests to assert against it deterministically
/// right after the call that triggered it — an actor-hop via an unstructured
/// `Task` would make that racy.
public final class RecordingAnalyticsTracker: AnalyticsTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [AnalyticsEvent] = []

    public init() {}

    /// A point-in-time snapshot of every event recorded so far.
    public var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storedEvents
    }

    public func track(_ event: AnalyticsEvent) {
        lock.lock()
        storedEvents.append(event)
        lock.unlock()
    }
}
