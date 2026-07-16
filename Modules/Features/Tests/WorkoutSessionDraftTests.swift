import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

/// An in-memory `WorkoutSessionDraftStoring` fake for tests — no filesystem I/O, so
/// test runs never share real on-disk state (see `LiveWorkoutSessionDraftStore`'s
/// own round-trip test below for the real implementation).
/// Not `private` — also used by `WorkoutPlayerViewModelTests` to keep every
/// view model constructed there off the real `LiveWorkoutSessionDraftStore`
/// file. That matters for test isolation, not just style: the seeded Sam
/// Patel workout/engagement ids are deterministic and several of those tests
/// share the same fixed `InMemoryStore.referenceDate` clock, so two view
/// models built against the real default store in the same test run could
/// otherwise "restore" one another's draft mid-suite.
final class FakeWorkoutSessionDraftStore: WorkoutSessionDraftStoring, @unchecked Sendable {
    private(set) var draft: WorkoutSessionDraft?
    private(set) var cleared = false

    func save(_ draft: WorkoutSessionDraft) {
        self.draft = draft
        cleared = false
    }

    func load() -> WorkoutSessionDraft? {
        draft
    }

    func clear() {
        draft = nil
        cleared = true
    }
}

@Suite("WorkoutPlayerViewModel draft persistence")
@MainActor
struct WorkoutSessionDraftTests {
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

    @Test("logging a set saves a draft containing that set; a bodyweight edit also saves a draft")
    func loggingSetAndBodyweightSavesDraft() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let store = FakeWorkoutSessionDraftStore()

        let viewModel = WorkoutPlayerViewModel(
            backend: backend, engagementID: engagementID, workout: workout,
            clock: { InMemoryStore.referenceDate }, draftStore: store
        )
        viewModel.commitActiveSet(for: backSquat)

        let draftAfterSet = try #require(store.load())
        #expect(draftAfterSet.setLogsByExercise[backSquat.id]?.first?.logged == true)

        viewModel.bodyweightText = "184"
        let draftAfterBodyweight = try #require(store.load())
        #expect(draftAfterBodyweight.bodyweightText == "184")
    }

    @Test("a second view model with the same store, engagement, workout, and same-day clock restores logged sets, bodyweight, and startedAt")
    func matchingDraftIsRestored() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let store = FakeWorkoutSessionDraftStore()
        let clock: @Sendable () -> Date = { InMemoryStore.referenceDate }

        let first = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock, draftStore: store)
        first.commitActiveSet(for: backSquat)
        first.bodyweightText = "184"

        let second = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock, draftStore: store)
        #expect(second.startedAt == first.startedAt)
        #expect(second.bodyweightText == "184")
        #expect(second.setLogs(for: backSquat).first?.logged == true)
    }

    @Test("a draft with a mismatched workoutID is ignored on init, leaves fresh scaffolding untouched, and clears the store")
    func mismatchedWorkoutIDDraftIsIgnoredAndCleared() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let store = FakeWorkoutSessionDraftStore()
        let clock: @Sendable () -> Date = { InMemoryStore.referenceDate }

        store.save(
            WorkoutSessionDraft(
                engagementID: engagementID,
                workoutID: Identifier<Workout>(),
                startedAt: clock(),
                bodyweightText: "999",
                setLogsByExercise: [:],
                savedAt: clock()
            )
        )

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock, draftStore: store)
        #expect(viewModel.bodyweightText.isEmpty)
        #expect(viewModel.setLogs(for: backSquat).allSatisfy { !$0.logged })
        #expect(store.cleared)
        #expect(store.load() == nil)
    }

    @Test("a draft with a mismatched engagementID is ignored on init and clears the store")
    func mismatchedEngagementIDDraftIsIgnoredAndCleared() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let store = FakeWorkoutSessionDraftStore()
        let clock: @Sendable () -> Date = { InMemoryStore.referenceDate }

        store.save(
            WorkoutSessionDraft(
                engagementID: Identifier<Engagement>(),
                workoutID: workout.id,
                startedAt: clock(),
                bodyweightText: "999",
                setLogsByExercise: [:],
                savedAt: clock()
            )
        )

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock, draftStore: store)
        #expect(viewModel.bodyweightText.isEmpty)
        #expect(store.cleared)
    }

    @Test("a draft saved on a prior day is discarded on init and the store is cleared")
    func staleDraftFromPriorDayIsDiscardedAndCleared() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let backSquat = try #require(workout.exercises.first { $0.exercise.name == "Back Squat" })
        let store = FakeWorkoutSessionDraftStore()
        let savingClock: @Sendable () -> Date = { InMemoryStore.referenceDate }
        let restoringClock: @Sendable () -> Date = { InMemoryStore.referenceDate.addingTimeInterval(2 * 86_400) }

        let first = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: savingClock, draftStore: store)
        first.commitActiveSet(for: backSquat)

        let second = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: restoringClock, draftStore: store)
        #expect(second.setLogs(for: backSquat).allSatisfy { !$0.logged })
        #expect(store.cleared)
    }

    @Test("completeWorkout succeeding clears the draft store")
    func completingWorkoutClearsDraftStore() async throws {
        let backend = InMemoryStore.seeded()
        let (engagementID, workout) = try await samPatelLowerBodyWorkout(backend: backend)
        let store = FakeWorkoutSessionDraftStore()

        let viewModel = WorkoutPlayerViewModel(
            backend: backend, engagementID: engagementID, workout: workout,
            clock: { InMemoryStore.referenceDate }, draftStore: store
        )
        viewModel.bodyweightText = "184"
        #expect(store.load() != nil)

        let completed = await viewModel.completeWorkout()
        #expect(completed)
        #expect(store.load() == nil)
    }

    @Test("LiveWorkoutSessionDraftStore round-trips a draft through disk, and clear() removes it")
    func liveWorkoutSessionDraftStoreRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LiveWorkoutSessionDraftStore(directory: directory)

        let draft = WorkoutSessionDraft(
            engagementID: Identifier<Engagement>(),
            workoutID: Identifier<Workout>(),
            startedAt: InMemoryStore.referenceDate,
            bodyweightText: "184",
            setLogsByExercise: [
                Identifier<ExercisePrescription>(): [
                    WorkoutPlayerViewModel.SetLog(id: 0, reps: "5", weightText: "225", logged: true),
                ],
            ],
            savedAt: InMemoryStore.referenceDate
        )

        store.save(draft)
        let loaded = try #require(store.load())
        #expect(loaded == draft)

        store.clear()
        #expect(store.load() == nil)
    }
}
