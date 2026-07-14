import Domain
import Foundation
import UserNotifications

/// The real `SessionReminderScheduling` implementation, backed by
/// `UNUserNotificationCenter` local notifications. `Features` may import
/// `UserNotifications` (an Apple system framework, not a concrete backend
/// adapter) — see docs/ARCHITECTURE.md.
///
/// Stateless by design: every method looks up
/// `UNUserNotificationCenter.current()` fresh rather than storing an
/// instance, so this type stays trivially `Sendable` regardless of the
/// system class's own concurrency annotations.
public struct LiveSessionReminderScheduler: SessionReminderScheduling {
    /// How far ahead of a session's `scheduledAt` the reminder fires.
    public static let leadTime: TimeInterval = 60 * 60 // 60 minutes

    public init() {}

    public func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func scheduleReminder(for session: Session, clientName: String) async {
        guard session.status == .scheduled else { return }
        let fireDate = session.scheduledAt.addingTimeInterval(-Self.leadTime)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming session"
        content.body = "Session with \(clientName) at \(session.scheduledAt.formatted(date: .omitted, time: .shortened))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.identifier(for: session.id), content: content, trigger: trigger)

        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { _ in
                continuation.resume()
            }
        }
    }

    public func cancelReminder(for sessionID: Identifier<Session>) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: sessionID)])
    }

    private static func identifier(for sessionID: Identifier<Session>) -> String {
        "session-reminder-\(sessionID.rawValue)"
    }
}
