import Domain
import Foundation
import Testing
@testable import Features

@Suite("ConsumerProgramSummaries")
struct ConsumerProgramSummariesTests {
    private static let calendar = Calendar(identifier: .gregorian)

    private func week(_ index: Int, workouts: [Workout]) -> ProgramWeek {
        ProgramWeek(id: Identifier(), index: index, workouts: workouts)
    }

    private func workout(_ name: String, exercises: [ExercisePrescription] = []) -> Workout {
        Workout(id: Identifier(), name: name, exercises: exercises)
    }

    @Test("currentWorkout picks the week matching elapsed whole weeks since startDate")
    func picksWeekByElapsedTime() {
        let start = Date(timeIntervalSince1970: 0)
        let program = Program(
            id: Identifier(),
            authorID: Identifier(),
            title: "Test Program",
            summary: "",
            weeks: [week(0, workouts: [workout("Week 1 Workout")]), week(1, workouts: [workout("Week 2 Workout")])]
        )

        let weekZero = ConsumerProgramSummaries.currentWorkout(program: program, startDate: start, now: start.addingTimeInterval(3 * 86_400), calendar: Self.calendar)
        #expect(weekZero?.week.index == 0)
        #expect(weekZero?.workout.name == "Week 1 Workout")

        let weekOne = ConsumerProgramSummaries.currentWorkout(program: program, startDate: start, now: start.addingTimeInterval(9 * 86_400), calendar: Self.calendar)
        #expect(weekOne?.week.index == 1)
        #expect(weekOne?.workout.name == "Week 2 Workout")
    }

    @Test("currentWorkout clamps to the program's last week once the client has run past its length")
    func clampsToLastWeek() {
        let start = Date(timeIntervalSince1970: 0)
        let program = Program(
            id: Identifier(),
            authorID: Identifier(),
            title: "Short Program",
            summary: "",
            weeks: [week(0, workouts: [workout("Only Workout")])]
        )

        let farInTheFuture = ConsumerProgramSummaries.currentWorkout(
            program: program,
            startDate: start,
            now: start.addingTimeInterval(200 * 86_400),
            calendar: Self.calendar
        )
        #expect(farInTheFuture?.week.index == 0)
        #expect(farInTheFuture?.workout.name == "Only Workout")
    }

    @Test("currentWorkout returns nil for a program with no weeks")
    func nilForEmptyProgram() {
        let program = Program(id: Identifier(), authorID: Identifier(), title: "Empty", summary: "", weeks: [])
        let result = ConsumerProgramSummaries.currentWorkout(program: program, startDate: Date(), now: Date(), calendar: Self.calendar)
        #expect(result == nil)
    }

    @Test("metricKind maps the big barbell lifts and returns nil for accessory/bodyweight exercises")
    func metricKindMapping() {
        #expect(ConsumerProgramSummaries.metricKind(forExerciseNamed: "Back Squat") == .squat1RM)
        #expect(ConsumerProgramSummaries.metricKind(forExerciseNamed: "Bench Press") == .bench1RM)
        #expect(ConsumerProgramSummaries.metricKind(forExerciseNamed: "Deadlift") == .deadlift1RM)
        #expect(ConsumerProgramSummaries.metricKind(forExerciseNamed: "Goblet Squat") == nil)
        #expect(ConsumerProgramSummaries.metricKind(forExerciseNamed: "Plank") == nil)
    }

    @Test("primaryEngagement prefers the most-recently-started active engagement")
    func primaryEngagementPrefersActive() {
        let now = Date()
        let ended = Engagement(id: Identifier(), clientID: Identifier(), professionalID: Identifier(), status: .ended, startedAt: now.addingTimeInterval(-500 * 86_400), endedAt: now.addingTimeInterval(-400 * 86_400))
        let olderActive = Engagement(id: Identifier(), clientID: Identifier(), professionalID: Identifier(), status: .active, startedAt: now.addingTimeInterval(-100 * 86_400), endedAt: nil)
        let newerActive = Engagement(id: Identifier(), clientID: Identifier(), professionalID: Identifier(), status: .active, startedAt: now.addingTimeInterval(-10 * 86_400), endedAt: nil)

        let chosen = ConsumerProgramSummaries.primaryEngagement([ended, olderActive, newerActive])
        #expect(chosen?.id == newerActive.id)
    }

    @Test("primaryEngagement falls back to the most-recently-started engagement when none are active")
    func primaryEngagementFallsBackWhenNoneActive() {
        let now = Date()
        let older = Engagement(id: Identifier(), clientID: Identifier(), professionalID: Identifier(), status: .paused, startedAt: now.addingTimeInterval(-100 * 86_400), endedAt: nil)
        let newer = Engagement(id: Identifier(), clientID: Identifier(), professionalID: Identifier(), status: .completed, startedAt: now.addingTimeInterval(-10 * 86_400), endedAt: now.addingTimeInterval(-5 * 86_400))

        let chosen = ConsumerProgramSummaries.primaryEngagement([older, newer])
        #expect(chosen?.id == newer.id)
    }

    @Test("primaryEngagement returns nil for an empty list")
    func primaryEngagementEmptyList() {
        #expect(ConsumerProgramSummaries.primaryEngagement([]) == nil)
    }

    @Test("estimatedDurationMinutes derives from total prescribed sets, rounded to the nearest 5 with a 10-minute floor")
    func estimatedDurationMinutesRoundsAndFloors() {
        let sixSets = workout("Six Sets", exercises: [
            ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Back Squat"), sets: 3, reps: "5", notes: nil),
            ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Bench Press"), sets: 3, reps: "5", notes: nil)
        ])
        #expect(ConsumerProgramSummaries.estimatedDurationMinutes(for: sixSets) == 20) // 6 sets * 3 = 18, rounds to 20

        let noExercises = workout("Empty", exercises: [])
        #expect(ConsumerProgramSummaries.estimatedDurationMinutes(for: noExercises) == 10) // floors at 10
    }

    @Test("heroMetaLine formats exercise count, estimated duration, and 1-based week number")
    func heroMetaLineFormats() {
        let program = workout("Full Body", exercises: [
            ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Goblet Squat"), sets: 3, reps: "12", notes: nil)
        ])
        #expect(ConsumerProgramSummaries.heroMetaLine(workout: program, weekIndex: 5) == "1 exercise · ~10 min · Week 6")

        let twoExercise = workout("Full Body", exercises: [
            ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Goblet Squat"), sets: 3, reps: "12", notes: nil),
            ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Push-up"), sets: 3, reps: "10", notes: nil)
        ])
        #expect(ConsumerProgramSummaries.heroMetaLine(workout: twoExercise, weekIndex: 0) == "2 exercises · ~20 min · Week 1")
    }

    @Test("weeklySessionSummary counts only sessions in now's calendar week, nil when none fall in it")
    func weeklySessionSummaryCountsCurrentWeekOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_700_000_000) // a Tuesday
        let engagementID = Identifier<Engagement>()
        let inWeekCompleted = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-1 * 3_600), status: .completed)
        let inWeekScheduled = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(2 * 3_600), status: .scheduled)
        let outsideWeek = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-30 * 86_400), status: .completed)

        let summary = ConsumerProgramSummaries.weeklySessionSummary(sessions: [inWeekCompleted, inWeekScheduled, outsideWeek], now: now, calendar: calendar)
        #expect(summary?.completed == 1)
        #expect(summary?.total == 2)

        let none = ConsumerProgramSummaries.weeklySessionSummary(sessions: [outsideWeek], now: now, calendar: calendar)
        #expect(none == nil)
    }

    // MARK: - Workout Player: session totals, "last time", top-set comparison

    @Test("sessionTotals sums weight × reps across every logged set and measures wall-clock duration")
    func sessionTotalsSumsVolumeAndDuration() {
        let start = Date(timeIntervalSince1970: 0)
        let loggedSets = [
            ConsumerProgramSummaries.LoggedSetSummary(weight: 185, reps: 5),
            ConsumerProgramSummaries.LoggedSetSummary(weight: 185, reps: 5),
            ConsumerProgramSummaries.LoggedSetSummary(weight: 135, reps: 12)
        ]
        let totals = ConsumerProgramSummaries.sessionTotals(loggedSets: loggedSets, startedAt: start, completedAt: start.addingTimeInterval(47 * 60 + 12))

        let expectedVolume: Double = 185 * 5 + 185 * 5 + 135 * 12
        #expect(totals.totalSetsLogged == 3)
        #expect(totals.poundsMoved == expectedVolume)
        #expect(totals.durationSeconds == TimeInterval(47 * 60 + 12))
    }

    @Test("sessionTotals with no logged sets is a factual, empty roll-up, never negative duration")
    func sessionTotalsEmptyIsHonest() {
        let start = Date(timeIntervalSince1970: 100)
        let totals = ConsumerProgramSummaries.sessionTotals(loggedSets: [], startedAt: start, completedAt: start.addingTimeInterval(-5))

        #expect(totals.totalSetsLogged == 0)
        #expect(totals.poundsMoved == 0)
        #expect(totals.durationSeconds == 0) // clamped, never negative even if completedAt precedes startedAt
    }

    @Test("formattedDuration renders tabular m:ss, clamping negatives to 0:00")
    func formattedDurationRendersMinutesSeconds() {
        #expect(ConsumerProgramSummaries.formattedDuration(47 * 60 + 12) == "47:12")
        #expect(ConsumerProgramSummaries.formattedDuration(5) == "0:05")
        #expect(ConsumerProgramSummaries.formattedDuration(-10) == "0:00")
    }

    @Test("lastLoggedEntry picks the most recent entry strictly before `now`, ignoring same/future-dated entries")
    func lastLoggedEntryPicksMostRecentPriorEntry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let engagementID = Identifier<Engagement>()
        let older = ProgressEntry(id: Identifier(), engagementID: engagementID, metric: .squat1RM, value: MetricValue(value: 205, unit: .lb), recordedAt: now.addingTimeInterval(-14 * 86_400), source: .clientSelfReported)
        let recent = ProgressEntry(id: Identifier(), engagementID: engagementID, metric: .squat1RM, value: MetricValue(value: 220, unit: .lb), recordedAt: now.addingTimeInterval(-7 * 86_400), source: .clientSelfReported)
        let future = ProgressEntry(id: Identifier(), engagementID: engagementID, metric: .squat1RM, value: MetricValue(value: 230, unit: .lb), recordedAt: now.addingTimeInterval(3_600), source: .clientSelfReported)

        let last = ConsumerProgramSummaries.lastLoggedEntry(entries: [older, recent, future], metric: .squat1RM, before: now)
        #expect(last?.value.value == 220)

        #expect(ConsumerProgramSummaries.lastLoggedEntry(entries: [], metric: .squat1RM, before: now) == nil)
    }

    @Test("topSetComparison picks the first workout-order exercise with both a logged top weight and prior history")
    func topSetComparisonPicksFirstQualifyingExercise() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let backSquat = ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Back Squat"), sets: 3, reps: "5", notes: nil)
        let gobletSquat = ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Goblet Squat"), sets: 3, reps: "12", notes: nil)
        let deadlift = ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Deadlift"), sets: 1, reps: "5", notes: nil)
        let testWorkout = workout("Lower Body", exercises: [gobletSquat, backSquat, deadlift])

        let priorSquat = ProgressEntry(id: Identifier(), engagementID: Identifier(), metric: .squat1RM, value: MetricValue(value: 220, unit: .lb), recordedAt: now.addingTimeInterval(-7 * 86_400), source: .clientSelfReported)

        let comparison = ConsumerProgramSummaries.topSetComparison(
            workout: testWorkout,
            loggedTopWeightByExerciseID: [backSquat.id: 225, gobletSquat.id: 45],
            priorEntriesByMetric: [.squat1RM: [priorSquat]],
            now: now
        )
        #expect(comparison?.exerciseName == "Back Squat")
        #expect(comparison?.deltaValue == 5)
        #expect(comparison?.unit == .lb)
    }

    @Test("topSetComparison is nil when no exercise has both a logged top weight and prior history — never fabricated")
    func topSetComparisonNilWithoutHonestData() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let backSquat = ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Back Squat"), sets: 3, reps: "5", notes: nil)
        let testWorkout = workout("Lower Body", exercises: [backSquat])

        // No prior history at all.
        #expect(ConsumerProgramSummaries.topSetComparison(workout: testWorkout, loggedTopWeightByExerciseID: [backSquat.id: 225], priorEntriesByMetric: [:], now: now) == nil)

        // Prior history exists, but nothing was logged this session.
        let priorSquat = ProgressEntry(id: Identifier(), engagementID: Identifier(), metric: .squat1RM, value: MetricValue(value: 220, unit: .lb), recordedAt: now.addingTimeInterval(-7 * 86_400), source: .clientSelfReported)
        #expect(ConsumerProgramSummaries.topSetComparison(workout: testWorkout, loggedTopWeightByExerciseID: [:], priorEntriesByMetric: [.squat1RM: [priorSquat]], now: now) == nil)
    }
}
