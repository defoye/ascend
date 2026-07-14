import Domain

/// A call-recording spy `SessionReminderScheduling`, used by previews (via
/// `PreviewBackend`) and by `FeaturesTests` so booking/cancelling flows can
/// be asserted against without ever touching `UNUserNotificationCenter` or
/// prompting for real notification permission (see docs/TESTING.md).
///
/// An `actor` so concurrent calls from view-model code stay data-race free
/// while still satisfying `SessionReminderScheduling: Sendable`.
public actor MockSessionReminderScheduler: SessionReminderScheduling {
    public private(set) var didRequestAuthorization = false
    public private(set) var scheduledSessionIDs: [Identifier<Session>] = []
    public private(set) var cancelledSessionIDs: [Identifier<Session>] = []

    /// What `requestAuthorization()` returns; defaults to granted so
    /// previews and tests don't need to configure it explicitly.
    public var authorizationGranted = true

    public init() {}

    public func requestAuthorization() async -> Bool {
        didRequestAuthorization = true
        return authorizationGranted
    }

    public func scheduleReminder(for session: Session, clientName: String) async {
        scheduledSessionIDs.append(session.id)
    }

    public func cancelReminder(for sessionID: Identifier<Session>) async {
        cancelledSessionIDs.append(sessionID)
    }
}
