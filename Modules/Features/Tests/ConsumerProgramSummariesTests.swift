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
}
