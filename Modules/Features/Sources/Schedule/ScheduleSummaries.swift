import Domain
import Foundation

/// Which of the two schedule layouts is showing.
public enum ScheduleViewMode: String, Sendable, CaseIterable {
    case day = "Day"
    case week = "Week"
}

/// A `Session` paired with the display name of the client it belongs to, for
/// the schedule's day/week lists. Mirrors `Today`'s `UpcomingSession`, but
/// covers every status (past and future), not just `.scheduled`.
public struct ScheduledSession: Sendable, Identifiable, Equatable {
    public let session: Session
    public let clientName: String

    public init(session: Session, clientName: String) {
        self.session = session
        self.clientName = clientName
    }

    public var id: Identifier<Session> { session.id }
    public var scheduledAt: Date { session.scheduledAt }
    public var status: SessionStatus { session.status }
    public var engagementID: Identifier<Engagement> { session.engagementID }
}

/// Pure, directly-testable math behind the coach schedule: date-range
/// filtering, day grouping, and navigation. Kept free of any backend/view-model
/// dependency so tests can exercise it straight against fixtures (see
/// docs/TESTING.md).
public enum ScheduleSummaries {
    /// Sessions whose `scheduledAt` falls on the same calendar day as `date`.
    public static func sessions(_ sessions: [ScheduledSession], on date: Date, calendar: Calendar = .current) -> [ScheduledSession] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return sessions
            .filter { $0.scheduledAt >= start && $0.scheduledAt < end }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// The `Calendar`-defined week (e.g. Sun-Sat) containing `date`.
    public static func weekInterval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
    }

    /// Sessions whose `scheduledAt` falls within the calendar week containing `date`.
    public static func sessions(_ sessions: [ScheduledSession], inWeekContaining date: Date, calendar: Calendar = .current) -> [ScheduledSession] {
        let interval = weekInterval(containing: date, calendar: calendar)
        return sessions
            .filter { interval.contains($0.scheduledAt) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// One calendar day's worth of sessions, for grouped display.
    public struct DayGroup: Sendable, Identifiable, Equatable {
        public let date: Date
        public let sessions: [ScheduledSession]
        public var id: Date { date }
    }

    /// Groups `sessions` by calendar day, ascending by date, each day's
    /// sessions ascending by time.
    public static func groupedByDay(_ sessions: [ScheduledSession], calendar: Calendar = .current) -> [DayGroup] {
        let grouped = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.scheduledAt) }
        return grouped.keys.sorted().map { day in
            DayGroup(date: day, sessions: (grouped[day] ?? []).sorted { $0.scheduledAt < $1.scheduledAt })
        }
    }

    // MARK: - Navigation

    public static func nextDay(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: date) ?? date
    }

    public static func previousDay(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -1, to: date) ?? date
    }

    public static func nextWeek(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
    }

    public static func previousWeek(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -1, to: date) ?? date
    }

    /// The availability windows (see `AvailabilityWindow`) that apply to the
    /// calendar weekday of `date`, ordered by start time.
    public static func windows(_ windows: [AvailabilityWindow], on date: Date, calendar: Calendar = .current) -> [AvailabilityWindow] {
        let weekday = calendar.component(.weekday, from: date)
        return windows
            .filter { $0.weekday == weekday }
            .sorted { $0.startMinute < $1.startMinute }
    }
}
