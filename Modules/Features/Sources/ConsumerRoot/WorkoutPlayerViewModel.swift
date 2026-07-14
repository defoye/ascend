import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the client's workout player: step through an assigned
/// `Workout`'s exercises, log sets/reps/weight, and mark the workout
/// complete.
///
/// Per-set logging is local UI state — docs/DATA_MODEL.md has no "logged
/// set" entity, and inventing one isn't warranted for this slice. What
/// actually persists on completion, through existing repositories:
///   - a `.clientSelfReported` `ProgressEntry` (`ProgressRepository`) for
///     any exercise whose name maps to a `MetricKind`
///     (`ConsumerProgramSummaries.metricKind(forExerciseNamed:)`, e.g. "Back
///     Squat" -> `.squat1RM`) with a logged weight, using the heaviest
///     logged set for that exercise;
///   - if today's scheduled session for this engagement exists, it's
///     transitioned to `.completed` (`SessionRepository`) — the "activity"
///     pillar `VerifiedOutcome.derive` needs.
/// Completing requires at least one numeric input (a set weight, or the
/// optional bodyweight check-in) so "complete" always writes real evidence,
/// never a no-op.
@MainActor
@Observable
public final class WorkoutPlayerViewModel {
    /// One logged set for a single exercise: reps and weight are free text
    /// so the client can log an unfinished/partial set without the field
    /// rejecting input mid-edit.
    public struct SetLog: Sendable, Identifiable, Equatable {
        public let id: Int
        public var reps: String
        public var weightText: String

        public init(id: Int, reps: String, weightText: String = "") {
            self.id = id
            self.reps = reps
            self.weightText = weightText
        }
    }

    public let workout: Workout
    public private(set) var setLogsByExercise: [Identifier<ExercisePrescription>: [SetLog]] = [:]
    public var bodyweightText = ""
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?
    public private(set) var isCompleted = false

    private let backend: any Backend
    private let engagementID: Identifier<Engagement>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        engagementID: Identifier<Engagement>,
        workout: Workout,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.engagementID = engagementID
        self.workout = workout
        self.clock = clock

        for exercise in workout.exercises {
            setLogsByExercise[exercise.id] = (0..<max(exercise.sets, 1)).map { SetLog(id: $0, reps: exercise.reps) }
        }
    }

    public func setLogs(for exercise: ExercisePrescription) -> [SetLog] {
        setLogsByExercise[exercise.id] ?? []
    }

    public func updateSetLog(_ log: SetLog, for exercise: ExercisePrescription) {
        guard var logs = setLogsByExercise[exercise.id], let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[index] = log
        setLogsByExercise[exercise.id] = logs
    }

    /// Whether there's at least one numeric input to log — a set weight or
    /// the bodyweight check-in — so "Finish workout" always writes real
    /// evidence.
    public var canComplete: Bool {
        if Double(bodyweightText) != nil { return true }
        return setLogsByExercise.values.contains { logs in logs.contains { Double($0.weightText) != nil } }
    }

    /// Persists the evidence described in this type's doc comment, then
    /// marks `isCompleted`. Returns `false` (writing nothing) when
    /// `canComplete` is `false`.
    @discardableResult
    public func completeWorkout() async -> Bool {
        guard canComplete else { return false }
        isSaving = true
        defer { isSaving = false }

        let now = clock()
        do {
            if let bodyweight = Double(bodyweightText) {
                try await logProgress(metric: .bodyweight, value: bodyweight, unit: .lb, at: now)
            }
            for exercise in workout.exercises {
                guard let metric = ConsumerProgramSummaries.metricKind(forExerciseNamed: exercise.exercise.name) else { continue }
                let weights = setLogs(for: exercise).compactMap { Double($0.weightText) }
                guard let topWeight = weights.max() else { continue }
                try await logProgress(metric: metric, value: topWeight, unit: .lb, at: now)
            }
            try await completeTodaysSessionIfAny(now: now)

            isCompleted = true
            saveErrorMessage = nil
            return true
        } catch {
            saveErrorMessage = "Couldn't save your workout. Try again."
            return false
        }
    }

    private func logProgress(metric: MetricKind, value: Double, unit: MetricUnit, at date: Date) async throws {
        let entry = ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: date,
            source: .clientSelfReported
        )
        _ = try await backend.progress.upsert(entry)
    }

    /// Marks this engagement's `.scheduled` session (if any) whose
    /// `scheduledAt` falls on `now`'s calendar day as `.completed` — the
    /// session "backing" today's workout, when one exists.
    private func completeTodaysSessionIfAny(now: Date) async throws {
        let sessions = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        let calendar = Calendar.current
        guard let todaysSession = sessions.first(where: { $0.status == .scheduled && calendar.isDate($0.scheduledAt, inSameDayAs: now) }) else {
            return
        }
        let completed = Session(
            id: todaysSession.id,
            engagementID: todaysSession.engagementID,
            scheduledAt: todaysSession.scheduledAt,
            status: .completed
        )
        _ = try await backend.sessions.upsert(completed)
    }
}
