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

    /// A rough, clearly-approximate workout duration: 3 minutes per
    /// prescribed set (covers the work + rest between sets), rounded to the
    /// nearest 5 minutes with a 10-minute floor. There's no logged-duration
    /// data to draw on (`WorkoutPlayerViewModel` doesn't time sessions), so
    /// this is a heuristic estimate only — always presented with a "~"
    /// prefix, never as a measured fact.
    public static func estimatedDurationMinutes(for workout: Workout) -> Int {
        let totalSets = workout.exercises.reduce(0) { $0 + $1.sets }
        let rounded = Int((Double(totalSets * 3) / 5).rounded()) * 5
        return max(10, rounded)
    }

    /// The hero workout card's meta line, e.g. "6 exercises · ~45 min · Week 6".
    public static func heroMetaLine(workout: Workout, weekIndex: Int) -> String {
        let exerciseCount = workout.exercises.count
        let minutes = estimatedDurationMinutes(for: workout)
        return "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") · ~\(minutes) min · Week \(weekIndex + 1)"
    }

    /// This calendar week's session completion for an engagement: how many
    /// of the sessions scheduled in `now`'s week are `.completed`, out of
    /// however many are scheduled. Returns `nil` when no sessions fall in
    /// the current week — there's nothing honest to report, so the caller
    /// should omit the "This week" card rather than show an empty "0 of 0".
    public struct WeeklySessionSummary: Sendable, Equatable {
        public let completed: Int
        public let total: Int

        public init(completed: Int, total: Int) {
            self.completed = completed
            self.total = total
        }
    }

    public static func weeklySessionSummary(
        sessions: [Session],
        now: Date,
        calendar: Calendar = .current
    ) -> WeeklySessionSummary? {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let thisWeek = sessions.filter { weekInterval.contains($0.scheduledAt) }
        guard !thisWeek.isEmpty else { return nil }
        return WeeklySessionSummary(completed: thisWeek.filter { $0.status == .completed }.count, total: thisWeek.count)
    }

    // MARK: - Workout Player: session totals, "last time", top-set comparison

    /// One committed set's weight and reps — the raw input to `sessionTotals`.
    public struct LoggedSetSummary: Sendable, Equatable {
        public let weight: Double
        public let reps: Int

        public init(weight: Double, reps: Int) {
            self.weight = weight
            self.reps = reps
        }
    }

    /// The Workout-complete screen's factual roll-up: total sets logged,
    /// wall-clock session duration, and total weight moved (Σ weight × reps
    /// across every logged set).
    public struct SessionTotals: Sendable, Equatable {
        public let totalSetsLogged: Int
        public let durationSeconds: TimeInterval
        public let poundsMoved: Double

        public init(totalSetsLogged: Int, durationSeconds: TimeInterval, poundsMoved: Double) {
            self.totalSetsLogged = totalSetsLogged
            self.durationSeconds = durationSeconds
            self.poundsMoved = poundsMoved
        }
    }

    public static func sessionTotals(
        loggedSets: [LoggedSetSummary],
        startedAt: Date,
        completedAt: Date
    ) -> SessionTotals {
        let poundsMoved = loggedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        return SessionTotals(
            totalSetsLogged: loggedSets.count,
            durationSeconds: max(0, completedAt.timeIntervalSince(startedAt)),
            poundsMoved: poundsMoved
        )
    }

    /// Formats a duration as tabular `m:ss` (e.g. `47:12`), for the elapsed
    /// header clock, the rest timer, and the complete-state "Duration" tile.
    public static func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// The most recently recorded entry for `metric` strictly before `now` —
    /// the "Last time" reference chip's data source. Only real, previously
    /// logged evidence; never fabricated.
    public static func lastLoggedEntry(
        entries: [ProgressEntry],
        metric: MetricKind,
        before now: Date
    ) -> ProgressEntry? {
        entries
            .filter { $0.metric == metric && $0.recordedAt < now }
            .max { $0.recordedAt < $1.recordedAt }
    }

    /// A factual top-set comparison for the Workout-complete success card:
    /// the first exercise (in workout order) that maps to a `MetricKind`,
    /// has a logged top weight from this session, and has a prior recorded
    /// entry for that metric to compare against. `nil` when no exercise in
    /// the workout has both — the card is omitted rather than fabricated.
    public struct TopSetComparison: Sendable, Equatable {
        public let exerciseName: String
        public let deltaValue: Double
        public let unit: MetricUnit

        public init(exerciseName: String, deltaValue: Double, unit: MetricUnit) {
            self.exerciseName = exerciseName
            self.deltaValue = deltaValue
            self.unit = unit
        }
    }

    public static func topSetComparison(
        workout: Workout,
        loggedTopWeightByExerciseID: [Identifier<ExercisePrescription>: Double],
        priorEntriesByMetric: [MetricKind: [ProgressEntry]],
        now: Date
    ) -> TopSetComparison? {
        for exercise in workout.exercises {
            guard
                let metric = metricKind(forExerciseNamed: exercise.exercise.name),
                let topWeight = loggedTopWeightByExerciseID[exercise.id],
                let prior = lastLoggedEntry(entries: priorEntriesByMetric[metric] ?? [], metric: metric, before: now)
            else { continue }
            return TopSetComparison(exerciseName: exercise.exercise.name, deltaValue: topWeight - prior.value.value, unit: prior.value.unit)
        }
        return nil
    }
}
