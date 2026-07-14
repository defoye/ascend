import Domain
import Foundation

/// Pure, directly-testable logic behind the client "Today" screen and
/// workout player — kept free of any backend/view-model dependency (mirrors
/// `TodaySummaries`/`ClientsSummaries`; see docs/TESTING.md).
public enum ConsumerProgramSummaries {
    /// A single week + workout picked out of an assigned `Program`, ready
    /// for the client's "Today's workout" card.
    public struct CurrentWorkout: Sendable, Equatable {
        public let week: ProgramWeek
        public let workout: Workout

        public init(week: ProgramWeek, workout: Workout) {
            self.week = week
            self.workout = workout
        }
    }

    /// Picks "today's" workout out of an assigned `Program`: the week whose
    /// 0-based index matches how many whole weeks have elapsed since the
    /// `ProgramAssignment.startDate` (clamped to the program's last week
    /// once the client has run past its length), and that week's first
    /// workout. Weeks aren't assumed to already be sorted by `index`.
    ///
    /// Returns `nil` for a program with no weeks, or a chosen week with no
    /// workouts.
    public static func currentWorkout(
        program: Program,
        startDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> CurrentWorkout? {
        let sortedWeeks = program.weeks.sorted { $0.index < $1.index }
        guard !sortedWeeks.isEmpty else { return nil }

        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: now)
        let elapsedDays = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let elapsedWeeks = max(0, elapsedDays / 7)
        let weekIndex = min(elapsedWeeks, sortedWeeks.count - 1)

        guard let workout = sortedWeeks[weekIndex].workouts.first else { return nil }
        return CurrentWorkout(week: sortedWeeks[weekIndex], workout: workout)
    }

    /// The `MetricKind` a strength exercise is a reasonable proxy for
    /// logging as a `ProgressEntry`, e.g. finishing a "Back Squat" set is
    /// evidence toward `squat1RM`. Only the big barbell lifts that have a
    /// direct `MetricKind` counterpart map to one — accessory/bodyweight
    /// exercises (goblet squats, planks, kettlebell swings, ...) return
    /// `nil` rather than being force-mapped to an approximate metric.
    public static func metricKind(forExerciseNamed name: String) -> MetricKind? {
        switch name {
        case "Back Squat": .squat1RM
        case "Bench Press": .bench1RM
        case "Deadlift": .deadlift1RM
        default: nil
        }
    }

    /// The engagement a client's "Today" dashboard should center on, when
    /// they have more than one: the most-recently-started `.active`
    /// engagement, falling back to the most-recently-started engagement of
    /// any status, or `nil` if the client has no engagements at all.
    public static func primaryEngagement(_ engagements: [Engagement]) -> Engagement? {
        let mostRecentlyStartedFirst = engagements.sorted {
            ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
        }
        if let active = mostRecentlyStartedFirst.first(where: { $0.status == .active }) {
            return active
        }
        return mostRecentlyStartedFirst.first
    }
}
