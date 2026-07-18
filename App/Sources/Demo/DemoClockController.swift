#if DEBUG

import Foundation
import Observation

/// Thread-safe storage for the demo clock's current instant. The
/// `@Sendable () -> Date` closures `CoachRootView`/`ConsumerRootView` accept
/// are plain, nonisolated, synchronous functions (see `AscendApp`'s
/// `demoClock`) — they cannot `await` into `@MainActor`-isolated state (the
/// same constraint docs/BACKEND.md documents for why `PaymentsMode`
/// isn't a `@MainActor`-backed runtime toggle), so the value the demo
/// control panel edits lives in this lock-protected box instead of an
/// `@Observable` class.
final class DemoClockBox: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date

    init(date: Date) {
        self.date = date
    }

    var current: Date {
        lock.lock()
        defer { lock.unlock() }
        return date
    }

    func set(_ newDate: Date) {
        lock.lock()
        defer { lock.unlock() }
        date = newDate
    }
}

/// The `@MainActor`/`@Observable` UI-facing wrapper the demo control panel
/// binds a `DatePicker` to; every write also updates the `DemoClockBox` the
/// actual `clock` closure reads.
@MainActor
@Observable
final class DemoClockController {
    private let box: DemoClockBox

    var currentDate: Date {
        didSet { box.set(currentDate) }
    }

    init(initialDate: Date) {
        box = DemoClockBox(date: initialDate)
        currentDate = initialDate
    }

    /// The `@Sendable () -> Date` clock closure to hand to `CoachRootView`/
    /// `ConsumerRootView`.
    var clock: @Sendable () -> Date {
        let box = box
        return { box.current }
    }
}

#endif
