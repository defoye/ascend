import Domain
import Foundation

/// A roster row: an `Engagement` joined with its client's display name,
/// primary goal, and last-activity timestamp, ready for `ClientsListView`.
public struct ClientRosterItem: Sendable, Identifiable, Equatable {
    public let engagement: Engagement
    public let clientName: String
    public let primaryGoal: GoalKind?
    public let lastActiveAt: Date?

    public init(
        engagement: Engagement,
        clientName: String,
        primaryGoal: GoalKind?,
        lastActiveAt: Date?
    ) {
        self.engagement = engagement
        self.clientName = clientName
        self.primaryGoal = primaryGoal
        self.lastActiveAt = lastActiveAt
    }

    public var id: Identifier<Engagement> { engagement.id }
    public var status: EngagementStatus { engagement.status }
}

/// Pure, directly-testable logic behind the coach "Clients" roster — kept
/// free of any backend/view-model dependency (mirrors `TodaySummaries`; see
/// docs/TESTING.md).
public enum ClientsSummaries {
    /// The most recent timestamp across an engagement's sessions
    /// (`scheduledAt`), progress entries (`recordedAt`), and messages
    /// (`sentAt`) — or `nil` if the engagement has no activity at all.
    public static func lastActivity(
        sessions: [Session],
        progress: [ProgressEntry],
        messages: [Message]
    ) -> Date? {
        let dates = sessions.map(\.scheduledAt) + progress.map(\.recordedAt) + messages.map(\.sentAt)
        return dates.max()
    }

    /// Filters a roster to a single `EngagementStatus`; `nil` means "All".
    public static func filter(_ items: [ClientRosterItem], status: EngagementStatus?) -> [ClientRosterItem] {
        guard let status else { return items }
        return items.filter { $0.status == status }
    }

    /// Case-insensitive substring match on client name; a blank query returns
    /// everything unfiltered.
    public static func search(_ items: [ClientRosterItem], query: String) -> [ClientRosterItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.clientName.localizedCaseInsensitiveContains(trimmed) }
    }

    /// How consistently a client has kept up completed sessions since the
    /// engagement started, for the Client Detail "Retention" stat tile (see
    /// docs/design/handoff/HANDOFF_README.md §02). `nil` when there's
    /// nothing to measure yet (no completed sessions, or the engagement
    /// hasn't started) — the caller renders a "—" placeholder rather than a
    /// fabricated number.
    public struct SessionRetention: Sendable, Equatable {
        public let percent: Int
        public let weeksWithSession: Int
        public let elapsedWeeks: Int

        public init(percent: Int, weeksWithSession: Int, elapsedWeeks: Int) {
            self.percent = percent
            self.weeksWithSession = weeksWithSession
            self.elapsedWeeks = elapsedWeeks
        }
    }

    /// The fraction of elapsed weeks (since `start`, through `now`) that
    /// contain at least one completed session — an honest consistency
    /// measure derived only from real session data, never a hardcoded or
    /// name-keyed number.
    public static func sessionRetention(
        completedSessionDates: [Date],
        since start: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> SessionRetention? {
        guard !completedSessionDates.isEmpty, start <= now else { return nil }
        let elapsedWeeks = max(1, (calendar.dateComponents([.weekOfYear], from: start, to: now).weekOfYear ?? 0) + 1)
        let weekKeys = Set(completedSessionDates.map { calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0) })
        let weeksWithSession = min(weekKeys.count, elapsedWeeks)
        let percent = Int((Double(weeksWithSession) / Double(elapsedWeeks) * 100).rounded())
        return SessionRetention(percent: percent, weeksWithSession: weeksWithSession, elapsedWeeks: elapsedWeeks)
    }

    /// The default roster ordering: active engagements first, then pending,
    /// paused, completed, ended; alphabetical by client name within each
    /// group.
    public static func sortedRoster(_ items: [ClientRosterItem]) -> [ClientRosterItem] {
        items.sorted { lhs, rhs in
            let lhsOrder = statusSortOrder(lhs.status)
            let rhsOrder = statusSortOrder(rhs.status)
            if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
            return lhs.clientName.localizedCaseInsensitiveCompare(rhs.clientName) == .orderedAscending
        }
    }

    private static func statusSortOrder(_ status: EngagementStatus) -> Int {
        switch status {
        case .active: 0
        case .pending: 1
        case .paused: 2
        case .completed: 3
        case .ended: 4
        }
    }
}

extension GoalKind {
    /// Human-readable label for a goal kind, e.g. for chips and subtitles.
    var displayName: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .buildMuscle: "Build muscle"
        case .getStronger: "Get stronger"
        case .improveMobility: "Improve mobility"
        case .recoverFromInjury: "Recover from injury"
        case .trainForSport: "Train for sport"
        case .improveEndurance: "Improve endurance"
        case .generalHealth: "General health"
        }
    }
}

extension EngagementStatus {
    /// Human-readable label for an engagement status.
    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        case .ended: "Ended"
        }
    }
}

extension MetricUnit {
    /// A short unit label, e.g. for `ProgressChart`'s `unit` parameter.
    var shortLabel: String {
        switch self {
        case .lb: "lb"
        case .kg: "kg"
        case .inch: "in"
        case .cm: "cm"
        case .percent: "%"
        case .bpm: "bpm"
        case .seconds: "sec"
        }
    }
}
