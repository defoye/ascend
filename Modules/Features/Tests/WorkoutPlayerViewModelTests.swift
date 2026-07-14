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

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate })
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

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate })
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

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { InMemoryStore.referenceDate })
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

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { now })
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

        let viewModel = WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: { now })
        viewModel.bodyweightText = "184"
        _ = await viewModel.completeWorkout()

        let updatedSession = try #require(try await backend.sessions.get(futureSession.id))
        #expect(updatedSession.status == .scheduled)
    }
}
