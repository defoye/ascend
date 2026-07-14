import Domain

/// A mockable seam over local session reminders, so `ScheduleViewModel`/
/// `BookSessionViewModel` logic stays testable without ever touching
/// `UNUserNotificationCenter` (and its permission prompt) in unit tests (see
/// docs/TESTING.md). `LiveSessionReminderScheduler` is the real
/// implementation; `MockSessionReminderScheduler` is a call-recording spy
/// used in previews and tests.
public protocol SessionReminderScheduling: Sendable {
    /// Requests local-notification authorization from the user. Returns
    /// whether it was granted.
    func requestAuthorization() async -> Bool

    /// Schedules a local reminder ahead of `session.scheduledAt` for a
    /// `.scheduled` session. Implementations should no-op for sessions whose
    /// reminder time has already passed.
    func scheduleReminder(for session: Session, clientName: String) async

    /// Removes any pending reminder for a session (e.g. after it's
    /// cancelled).
    func cancelReminder(for sessionID: Identifier<Session>) async
}
