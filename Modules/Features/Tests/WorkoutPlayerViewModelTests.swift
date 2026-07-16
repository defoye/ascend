import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("WorkoutPlayerViewModel against seeded data")
@MainActor
struct WorkoutPlayerViewModelTests {
    /// Sam Patel's assigned "Strength Foundations" week-0 workout: "Lower
    /// Body" — Back Squat (maps to `.squat1RM`) and Deadlift (maps to
    /// `.deadlift1RM`); see `MockData+Programs.swift`.
    private func samPatelLowerBodyWorkout(backend: InMemoryBackend) async throws -> (engagementID: Identifier<Engagement>, workout: Workout) {
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)
        let assignments = try await backend.programs.assignments(forEngagement: engagement.id)
        let assignment = try #require(assignments.first)
        let program = try #require(try await backend.programs.get(assignment.programID))
        let workout = try #require(program.weeks.first { $0.index == 0 }?.workouts.first)
        return (engagement.id, workout)
    }

    @Test("completing a workout with a logged exercise weight persists a clientSelfReported ProgressEntry for the mapped metric")
    func completingLogsMappedExerciseProgress() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())
        var firstSet = try #require(viewModel.setLogs(for: backSquat).first)
        firstSet.weightText = "230"
        viewModel.updateSetLog(firstSet, for: backSquat)

        #expect(viewModel.canComplete)
        let completed = await viewModel.completeWorkout()
        #expect(completed)
        #expect(viewModel.isCompleted)

        let persisted = try await backend.progress.fetchEntries(forEngagement: engagementID, metric: .squat1RM)
        #expect(persisted.contains { $0.value.value == 230 && $0.source == .clientSelfReported })
    }

    @Test("completing a workout with only a bodyweight check-in persists a clientSelfReported bodyweight entry")
    func completingLogsBodyweightCheckIn() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())
        viewModel.bodyweightText = "184"

        #expect(viewModel.canComplete)
        let completed = await viewModel.completeWorkout()
        #expect(completed)

        let persisted = try await backend.progress.fetchEntries(forEngagement: engagementID, metric: .bodyweight)
        #expect(persisted.contains { $0.value.value == 184 && $0.source == .clientSelfReported })
    }

    @Test("completing a workout with nothing logged is a no-op: canComplete is false and nothing new is persisted")
    func completingWithNothingLoggedIsNoOp() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let squatEntriesBefore = try await backend.progress.fetchEntries(forEngagement: engagementID, metric: .squat1RM)

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())
        #expect(!viewModel.canComplete)

        let completed = await viewModel.completeWorkout()
        #expect(!completed)
        #expect(!viewModel.isCompleted)

        // Sam Patel's engagement already has seeded (coach-recorded) squat1RM
        // history — this asserts completeWorkout() added no *new* entry, not
        // that the metric has never been logged before.
        let squatEntriesAfter = try await backend.progress.fetchEntries(forEngagement: engagementID, metric: .squat1RM)
        #expect(squatEntriesAfter.count == squatEntriesBefore.count)
    }

    @Test("completing a workout marks a same-day .scheduled session .completed — the activity pillar VerifiedOutcome.derive needs")
    func completingMarksSameDaySessionCompleted() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let now = InMemoryStore.referenceDate

        let todaysSession = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(3_600), status: .scheduled)
        _ = try await backend.sessions.upsert(todaysSession)

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { now }, draftStore: FakeWorkoutSessionDraftStore())
        viewModel.bodyweightText = "184"
        let completed = await viewModel.completeWorkout()
        #expect(completed)

        let updatedSession = try #require(try await backend.sessions.get(todaysSession.id))
        #expect(updatedSession.status == .completed)
    }

    @Test("completing a workout does not touch a session scheduled on a different day")
    func completingLeavesOtherDaySessionsAlone() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let now = InMemoryStore.referenceDate

        let futureSession = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(5 * 86_400), status: .scheduled)
        _ = try await backend.sessions.upsert(futureSession)

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { now }, draftStore: FakeWorkoutSessionDraftStore())
        viewModel.bodyweightText = "184"
        _ = await viewModel.completeWorkout()

        let updatedSession = try #require(try await backend.sessions.get(futureSession.id))
        #expect(updatedSession.status == .scheduled)
    }

    // MARK: - Set logging: commit, row state, exercise progress

    @Test("commitActiveSet marks the first not-yet-logged set logged and returns it; a blank reps commit is a no-op")
    func commitActiveSetMarksLoggedAndSkipsBlankReps() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())

        var firstSet = try #require(viewModel.setLogs(for: backSquat).first)
        firstSet.weightText = "225"
        viewModel.updateSetLog(firstSet, for: backSquat)

        let committed = try #require(viewModel.commitActiveSet(for: backSquat))
        #expect(committed.id == 0)
        #expect(committed.logged)
        #expect(viewModel.setLogs(for: backSquat)[0].logged)

        // The next set has default (non-blank) reps from the prescription, so it commits too...
        let secondCommit = viewModel.commitActiveSet(for: backSquat)
        #expect(secondCommit?.id == 1)

        // ...but a blank-reps set is left uncommitted.
        var thirdSet = try #require(viewModel.setLogs(for: backSquat).first { $0.id == 2 })
        thirdSet.reps = "  "
        viewModel.updateSetLog(thirdSet, for: backSquat)
        #expect(viewModel.commitActiveSet(for: backSquat) == nil)
        #expect(!viewModel.setLogs(for: backSquat)[2].logged)
    }

    @Test("setRowState reports done for logged sets, active for the first unlogged set, pending for the rest")
    func setRowStateReflectsPosition() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())

        viewModel.commitActiveSet(for: backSquat)
        let logs = viewModel.setLogs(for: backSquat)
        #expect(viewModel.setRowState(logs[0], for: backSquat) == .done)
        #expect(viewModel.setRowState(logs[1], for: backSquat) == .active)
        #expect(viewModel.setRowState(logs[2], for: backSquat) == .pending)
    }

    @Test("isExerciseFullyLogged and currentExerciseIndex advance only once every set in an exercise is logged")
    func exerciseProgressAdvancesOnceFullyLogged() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())

        #expect(viewModel.currentExerciseIndex == 0)
        #expect(!viewModel.isExerciseFullyLogged(backSquat))

        for _ in viewModel.setLogs(for: backSquat) {
            viewModel.commitActiveSet(for: backSquat)
        }

        #expect(viewModel.isExerciseFullyLogged(backSquat))
        #expect(viewModel.currentExerciseIndex == 1)
    }

    // MARK: - History: "Last time" chip, confirmation delta, top-set comparison

    @Test("loadHistory + lastLoggedEntry surfaces Sam Patel's seeded prior squat1RM entry for the mapped exercise")
    func loadHistorySurfacesLastLoggedEntry() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())

        #expect(viewModel.lastLoggedEntry(for: backSquat) == nil) // nothing fabricated before history loads

        await viewModel.loadHistory()
        let last = try #require(viewModel.lastLoggedEntry(for: backSquat))
        #expect(last.value.value == 225) // most recent of the seeded 185/205/225 entries (see MockData+Activity.swift)
    }

    @Test("confirmationCopy reports a factual weight delta vs. history, and an empty delta when there's no honest comparison")
    func confirmationCopyReportsFactualDeltaOrEmpty() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let walkingLunge = ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Walking Lunge"), sets: 1, reps: "12", notes: nil)
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate }, draftStore: FakeWorkoutSessionDraftStore())
        await viewModel.loadHistory()

        var squatSet = try #require(viewModel.setLogs(for: backSquat).first)
        squatSet.weightText = "230"
        viewModel.updateSetLog(squatSet, for: backSquat)
        let squatCopy = viewModel.confirmationCopy(for: squatSet, exercise: backSquat)
        #expect(squatCopy.value == "230 lb × 5")
        #expect(squatCopy.delta == "+5 lb vs. last logged") // 230 - 225 (seeded prior top)

        // An exercise with no MetricKind mapping has no history to compare against.
        let unmappedLog = WorkoutPlayerViewModel.SetLog(id: 0, reps: "12", weightText: "40")
        let unmappedCopy = viewModel.confirmationCopy(for: unmappedLog, exercise: walkingLunge)
        #expect(unmappedCopy.value == "40 lb × 12")
        #expect(unmappedCopy.delta.isEmpty)
    }

    @Test("sessionTotals and topSetComparison on the view model reflect only committed (logged) sets")
    func sessionTotalsAndTopSetComparisonReflectCommittedSetsOnly() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let now = InMemoryStore.referenceDate
        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { now }, draftStore: FakeWorkoutSessionDraftStore())
        await viewModel.loadHistory()

        // Typing a weight without committing shouldn't count toward totals or the comparison.
        var uncommitted = try #require(viewModel.setLogs(for: backSquat).first)
        uncommitted.weightText = "500"
        viewModel.updateSetLog(uncommitted, for: backSquat)
        #expect(viewModel.sessionTotals.totalSetsLogged == 0)
        #expect(viewModel.topSetComparison == nil)

        // Committing it makes it real evidence.
        let committed = try #require(viewModel.commitActiveSet(for: backSquat))
        #expect(committed.weightText == "500")
        #expect(viewModel.sessionTotals.totalSetsLogged == 1)
        #expect(viewModel.sessionTotals.poundsMoved == 500 * 5)

        let comparison = try #require(viewModel.topSetComparison)
        #expect(comparison.exerciseName == "Back Squat")
        #expect(comparison.deltaValue == 500 - 225)
    }
}
