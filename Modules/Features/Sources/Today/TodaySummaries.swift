import Domain
import Foundation

/// Net/gross revenue collected over a trailing window (see `TodaySummaries.revenueSummary`).
public struct RevenueSummary: Sendable, Equatable {
    public let netCents: Int
    public let grossCents: Int
    public let count: Int

    public init(netCents: Int, grossCents: Int, count: Int) {
        self.netCents = netCents
        self.grossCents = grossCents
        self.count = count
    }

    public static let zero = RevenueSummary(netCents: 0, grossCents: 0, count: 0)

    // swiftlint:disable:next empty_count
    public var isEmpty: Bool { count == 0 }
}

/// A `Session` paired with the display name of the client it belongs to, for
/// the "Upcoming sessions" list.
public struct UpcomingSession: Sendable, Identifiable, Equatable {
    public let session: Session
    public let clientName: String

    public init(session: Session, clientName: String) {
        self.session = session
        self.clientName = clientName
    }

    public var id: Identifier<Session> { session.id }
    public var scheduledAt: Date { session.scheduledAt }
}

/// One engagement's raw activity inputs, tagged with the client's display
/// name, ready to be folded into a cross-engagement feed by
/// `TodaySummaries.recentActivity`.
public struct EngagementActivity: Sendable {
    public let engagementID: Identifier<Engagement>
    public let clientName: String
    public let progress: [ProgressEntry]
    /// Messages authored by the client (not the professional) in this engagement.
    public let clientMessages: [Message]

    public init(
        engagementID: Identifier<Engagement>,
        clientName: String,
        progress: [ProgressEntry],
        clientMessages: [Message]
    ) {
        self.engagementID = engagementID
        self.clientName = clientName
        self.progress = progress
        self.clientMessages = clientMessages
    }
}

/// A single newest-first item in the "Recent client activity" feed: either a
/// new progress entry or a new client message.
public struct ActivityItem: Sendable, Identifiable, Equatable {
    public enum Kind: Sendable, Equatable {
        case progress(metric: MetricKind, value: MetricValue)
        case message(preview: String)
    }

    public let id: String
    public let engagementID: Identifier<Engagement>
    public let clientName: String
    public let kind: Kind
    public let occurredAt: Date

    public init(
        id: String,
        engagementID: Identifier<Engagement>,
        clientName: String,
        kind: Kind,
        occurredAt: Date
    ) {
        self.id = id
        self.engagementID = engagementID
        self.clientName = clientName
        self.kind = kind
        self.occurredAt = occurredAt
    }
}

/// Pure, directly-testable math behind the coach "Today" dashboard. Kept free
/// of any backend/view-model dependency so tests can exercise the arithmetic
/// straight against seeded fixtures (see docs/TESTING.md).
public enum TodaySummaries {
    /// Sessions that are still `.scheduled` and at or after `now`, soonest first.
    public static func upcomingSessions(from sessions: [Session], now: Date) -> [Session] {
        sessions
            .filter { $0.status == .scheduled && $0.scheduledAt >= now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    /// Net (`amountCents - platformFeeCents`) and gross revenue from
    /// `.succeeded` payments whose `createdAt` falls within the trailing
    /// `windowDays` days ending at (and including) `now`.
    public static func revenueSummary(
        from payments: [Payment],
        now: Date,
        windowDays: Int = 30
    ) -> RevenueSummary {
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let inWindow = payments.filter {
            $0.status == .succeeded && $0.createdAt >= windowStart && $0.createdAt <= now
        }
        let gross = inWindow.reduce(0) { $0 + $1.amountCents }
        let net = inWindow.reduce(0) { $0 + ($1.amountCents - $1.platformFeeCents) }
        return RevenueSummary(netCents: net, grossCents: gross, count: inWindow.count)
    }

    /// Folds each engagement's progress entries and client messages into a
    /// single newest-first feed, capped at `limit` items.
    public static func recentActivity(from sources: [EngagementActivity], limit: Int = 5) -> [ActivityItem] {
        var items: [ActivityItem] = []
        for source in sources {
            for entry in source.progress {
                items.append(
                    ActivityItem(
                        id: "progress-\(entry.id.rawValue)",
                        engagementID: source.engagementID,
                        clientName: source.clientName,
                        kind: .progress(metric: entry.metric, value: entry.value),
                        occurredAt: entry.recordedAt
                    )
                )
            }
            for message in source.clientMessages {
                items.append(
                    ActivityItem(
                        id: "message-\(message.id.rawValue)",
                        engagementID: source.engagementID,
                        clientName: source.clientName,
                        kind: .message(preview: message.body),
                        occurredAt: message.sentAt
                    )
                )
            }
        }
        return Array(items.sorted { $0.occurredAt > $1.occurredAt }.prefix(limit))
    }

    /// A short, `now`-relative label for a date: "Today", "Tomorrow", a
    /// weekday name for the rest of this week, or an abbreviated month/day
    /// further out. Deliberately independent of the real system clock so it
    /// stays correct against an injected/demo `now`.
    public static func relativeDayLabel(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        let startOfNow = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfDate).day ?? 0

        switch days {
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case 2..<7:
            return date.formatted(.dateTime.weekday(.wide))
        default:
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}
