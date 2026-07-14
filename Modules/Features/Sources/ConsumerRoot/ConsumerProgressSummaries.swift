import Domain
import Foundation

/// Pure, directly-testable milestone/streak math over a client's own
/// `ProgressEntry` history — kept free of any backend/view-model dependency
/// (mirrors `TodaySummaries`/`ClientsSummaries`; see docs/TESTING.md).
/// Backs the "My Progress" dashboard's milestone tiles.
public enum ConsumerProgressSummaries {
    /// A single milestone tile: a short label and a formatted value, ready
    /// to display in a `StatTile`.
    public struct Milestone: Sendable, Identifiable, Equatable {
        public let id: String
        public let label: String
        public let value: String

        public init(id: String, label: String, value: String) {
            self.id = id
            self.label = label
            self.value = value
        }
    }

    /// The number of consecutive calendar days, counting back from `now`'s
    /// day, that have at least one logged `ProgressEntry`. `0` if `now`'s
    /// day itself has no entry — the streak only counts days that are
    /// actually logged, never an implicit "grace day".
    public static func currentStreakDays(entries: [ProgressEntry], now: Date, calendar: Calendar = .current) -> Int {
        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.recordedAt) })
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        while loggedDays.contains(cursor) {
            streak += 1
            guard let priorDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = priorDay
        }
        return streak
    }

    /// The longest run of consecutive logged calendar days anywhere in
    /// `entries`' history (not just ending at `now`).
    public static func longestStreakDays(entries: [ProgressEntry], calendar: Calendar = .current) -> Int {
        let loggedDays = Set(entries.map { calendar.startOfDay(for: $0.recordedAt) }).sorted()
        guard let first = loggedDays.first else { return 0 }

        var longest = 1
        var current = 1
        var previousDay = first
        for day in loggedDays.dropFirst() {
            let expectedNextDay = calendar.date(byAdding: .day, value: 1, to: previousDay)
            if let expectedNextDay, calendar.isDate(expectedNextDay, inSameDayAs: day) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previousDay = day
        }
        return longest
    }

    /// Milestone tiles for the "My Progress" dashboard: total entries
    /// logged, current streak, longest streak, and — once there are at
    /// least two time-separated points for it — each tracked metric's
    /// directional delta from its first to its most recent entry. Order is
    /// stable: the three streak/count tiles first, then metrics in the
    /// order they first appear in `entries` (oldest-logged first).
    public static func milestones(from entries: [ProgressEntry], now: Date, calendar: Calendar = .current) -> [Milestone] {
        guard !entries.isEmpty else { return [] }

        var tiles: [Milestone] = [
            Milestone(id: "total", label: "Entries logged", value: "\(entries.count)"),
            Milestone(id: "streak", label: "Current streak", value: streakLabel(currentStreakDays(entries: entries, now: now, calendar: calendar))),
            Milestone(id: "longest-streak", label: "Longest streak", value: streakLabel(longestStreakDays(entries: entries, calendar: calendar)))
        ]

        for metric in orderedTrackedMetrics(entries) {
            guard let delta = metricDeltaLabel(entries: entries, metric: metric) else { continue }
            tiles.append(Milestone(id: "metric-\(metric.rawValue)", label: metric.milestoneLabel, value: delta))
        }
        return tiles
    }

    private static func streakLabel(_ days: Int) -> String {
        "\(days) day\(days == 1 ? "" : "s")"
    }

    /// Distinct metrics with logged entries, ordered by first-logged date.
    private static func orderedTrackedMetrics(_ entries: [ProgressEntry]) -> [MetricKind] {
        var seen: Set<MetricKind> = []
        var ordered: [MetricKind] = []
        for entry in entries.sorted(by: { $0.recordedAt < $1.recordedAt }) where seen.insert(entry.metric).inserted {
            ordered.append(entry.metric)
        }
        return ordered
    }

    /// A directional (▲/▼) delta string from a metric's first to most
    /// recent entry, or `nil` if fewer than two points are logged for it.
    private static func metricDeltaLabel(entries: [ProgressEntry], metric: MetricKind) -> String? {
        let points = entries.filter { $0.metric == metric }.sorted { $0.recordedAt < $1.recordedAt }
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        let change = last.value.value - first.value.value
        let arrow = change >= 0 ? "▲" : "▼"
        let magnitude = abs(change).formatted(.number.precision(.fractionLength(0...1)))
        return "\(arrow) \(magnitude) \(last.value.unit.shortLabel)"
    }
}

extension MetricKind {
    /// A short label for a metric's milestone tile, e.g. "Bodyweight change".
    fileprivate var milestoneLabel: String {
        switch self {
        case .bodyweight: "Bodyweight change"
        case .waistCircumference: "Waist change"
        case .squat1RM: "Squat 1RM change"
        case .bench1RM: "Bench 1RM change"
        case .deadlift1RM: "Deadlift 1RM change"
        case .bodyFatPercentage: "Body fat change"
        case .restingHeartRate: "Resting HR change"
        case .fiveKTime: "5K time change"
        }
    }
}
