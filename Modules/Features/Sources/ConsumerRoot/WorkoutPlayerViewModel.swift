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
///
/// A gym session means backgrounding the app dozens of times over 45-90
/// minutes, and iOS killing a backgrounded app mid-workout is the common
/// case, not an edge case — so the local UI state above (set logs,
/// bodyweight text, start time) is additionally mirrored to a local JSON
/// draft (`WorkoutSessionDraftStoring`) on every change, restored on `init` when it
/// still matches this engagement/workout and was saved today, and cleared on
/// successful completion. This is still local UI state, not a new persisted
/// entity — the draft only ever reconstructs what would otherwise have been
/// typed again this same session.
@MainActor
@Observable
public final class WorkoutPlayerViewModel {
    /// One logged set for a single exercise: reps and weight are free text
    /// so the client can log an unfinished/partial set without the field
    /// rejecting input mid-edit. `logged` flips to `true` only once the
    /// client commits the set (the "Log set N" affordance) — it's what
    /// drives the done/active/pending row states and the "logged"
    /// microinteraction, distinct from merely having typed a value.
    public struct SetLog: Sendable, Identifiable, Equatable, Codable {
        public let id: Int
        public var reps: String
        public var weightText: String
        public var logged: Bool

        public init(id: Int, reps: String, weightText: String = "", logged: Bool = false) {
            self.id = id
            self.reps = reps
            self.weightText = weightText
            self.logged = logged
        }
    }

    /// A set row's display state, driven by `logged` and position relative
    /// to the exercise's first not-yet-logged set (see docs/design/handoff/
    /// HANDOFF_README.md §05 "Set table (Set / Weight / Reps / ✓)").
    public enum SetRowState: Sendable, Equatable {
        case done, active, pending
    }

    public let workout: Workout
    public private(set) var startedAt: Date
    public private(set) var setLogsByExercise: [Identifier<ExercisePrescription>: [SetLog]] = [:]
    public var bodyweightText = "" {
        didSet { saveDraft() }
    }
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?
    public private(set) var isCompleted = false
    public private(set) var completedAt: Date?
    /// Prior `ProgressEntry` history for every exercise in this workout that
    /// maps to a `MetricKind`, keyed by that metric — backs the "Last time"
    /// reference chip and the complete-state top-set comparison. Populated
    /// by `loadHistory()`; empty (never fabricated) until then.
    public private(set) var priorEntriesByMetric: [MetricKind: [ProgressEntry]] = [:]

    private let backend: any Backend
    private let engagementID: Identifier<Engagement>
    private let clock: @Sendable () -> Date
    private let draftStore: any WorkoutSessionDraftStoring

    public init(
        backend: any Backend,
        engagementID: Identifier<Engagement>,
        workout: Workout,
        clock: @escaping @Sendable () -> Date = { Date() },
        draftStore: any WorkoutSessionDraftStoring = LiveWorkoutSessionDraftStore()
    ) {
        self.backend = backend
        self.engagementID = engagementID
        self.workout = workout
        self.clock = clock
        self.draftStore = draftStore
        self.startedAt = clock()

        for exercise in workout.exercises {
            setLogsByExercise[exercise.id] = (0..<max(exercise.sets, 1)).map { SetLog(id: $0, reps: exercise.reps) }
        }

        restoreDraftIfApplicable()
    }

    /// Adopts a persisted draft only when it still describes *this*
    /// player instance: same engagement, same workout, and saved earlier
    /// today. A draft for a different engagement/workout (the client
    /// switched programs, or started a different workout) or one left over
    /// from a prior day is discarded rather than adopted — a stale set log
    /// reappearing days later would be confusing, not helpful. Restoring is
    /// silent: no banner, no published "restored" flag, the state just
    /// reappears as if the app had never left.
    private func restoreDraftIfApplicable() {
        guard let draft = draftStore.load() else { return }
        guard
            draft.engagementID == engagementID,
            draft.workoutID == workout.id,
            Calendar.current.isDate(draft.savedAt, inSameDayAs: clock())
        else {
            draftStore.clear()
            return
        }

        startedAt = draft.startedAt
        for exerciseID in setLogsByExercise.keys {
            if let logs = draft.setLogsByExercise[exerciseID] {
                setLogsByExercise[exerciseID] = logs
            }
        }
        // Assigned last: `bodyweightText`'s `didSet` re-saves the draft, so
        // `setLogsByExercise` must already reflect the restored sets above —
        // otherwise the re-saved draft would overwrite the on-disk file with
        // stale (fresh-scaffolding) set logs before anything is re-logged.
        bodyweightText = draft.bodyweightText
    }

    /// Builds a `WorkoutSessionDraft` from current state and persists it —
    /// the single save path used by every mutation that should survive app
    /// termination (see the header doc comment).
    private func saveDraft() {
        draftStore.save(
            WorkoutSessionDraft(
                engagementID: engagementID,
                workoutID: workout.id,
                startedAt: startedAt,
                bodyweightText: bodyweightText,
                setLogsByExercise: setLogsByExercise,
                savedAt: clock()
            )
        )
    }

    public func setLogs(for exercise: ExercisePrescription) -> [SetLog] {
        setLogsByExercise[exercise.id] ?? []
    }

    public func updateSetLog(_ log: SetLog, for exercise: ExercisePrescription) {
        guard var logs = setLogsByExercise[exercise.id], let index = logs.firstIndex(where: { $0.id == log.id }) else { return }
        logs[index] = log
        setLogsByExercise[exercise.id] = logs
        saveDraft()
    }

    public func setRowState(_ log: SetLog, for exercise: ExercisePrescription) -> SetRowState {
        if log.logged { return .done }
        let firstUnlogged = setLogs(for: exercise).first { !$0.logged }
        return firstUnlogged?.id == log.id ? .active : .pending
    }

    /// Commits the exercise's current active (first not-yet-logged) set —
    /// the "Log set N" affordance — provided it has a non-empty reps value.
    /// Returns the committed set, or `nil` when there's no active set left
    /// or reps is blank (nothing invalid to commit).
    @discardableResult
    public func commitActiveSet(for exercise: ExercisePrescription) -> SetLog? {
        guard let active = setLogs(for: exercise).first(where: { !$0.logged }) else { return nil }
        guard !active.reps.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var committed = active
        committed.logged = true
        updateSetLog(committed, for: exercise)
        return committed
    }

    /// The "Set N logged · {weight} × {reps}" confirmation copy and a
    /// factual weight delta versus the last recorded entry for this
    /// exercise's mapped metric — empty when there's no honest comparison
    /// (unmapped exercise, no prior history, or no weight logged), never a
    /// fabricated number.
    public func confirmationCopy(for log: SetLog, exercise: ExercisePrescription) -> (value: String, delta: String) {
        let weight = Double(log.weightText)
        let value = weight.map { "\(Self.formattedWeight($0)) lb × \(log.reps)" } ?? "\(log.reps) reps"

        var delta = ""
        if let weight, let last = lastLoggedEntry(for: exercise) {
            let diff = weight - last.value.value
            let sign = diff >= 0 ? "+" : "−"
            delta = "\(sign)\(Self.formattedWeight(abs(diff))) \(last.value.unit.shortLabel) vs. last logged"
        }
        return (value, delta)
    }

    /// Whether every prescribed set for `exercise` has been logged.
    public func isExerciseFullyLogged(_ exercise: ExercisePrescription) -> Bool {
        let logs = setLogs(for: exercise)
        return !logs.isEmpty && logs.allSatisfy(\.logged)
    }

    /// 0-based index of the header's "EXERCISE i / n" and the segmented
    /// progress bar: the first exercise with an unlogged set, or the last
    /// exercise once everything is logged.
    public var currentExerciseIndex: Int {
        workout.exercises.firstIndex { !isExerciseFullyLogged($0) } ?? max(0, workout.exercises.count - 1)
    }

    /// One-shot fetch of prior progress history for every mapped exercise in
    /// this workout, so the "Last time" chip and complete-state top-set
    /// comparison have real data to draw on. Safe to call once per screen
    /// appearance; failures leave `priorEntriesByMetric` at its last-known
    /// (possibly empty) value rather than surfacing an error — this history
    /// is a nice-to-have annotation, not load-bearing for logging a set.
    public func loadHistory() async {
        var result: [MetricKind: [ProgressEntry]] = [:]
        for exercise in workout.exercises {
            guard
                let metric = ConsumerProgramSummaries.metricKind(forExerciseNamed: exercise.exercise.name),
                result[metric] == nil
            else { continue }
            result[metric] = (try? await backend.progress.fetchEntries(forEngagement: engagementID, metric: metric)) ?? []
        }
        priorEntriesByMetric = result
    }

    /// The most recent prior entry for `exercise`'s mapped metric, recorded
    /// before this session started — `nil` for unmapped exercises or ones
    /// with no history yet.
    public func lastLoggedEntry(for exercise: ExercisePrescription) -> ProgressEntry? {
        guard let metric = ConsumerProgramSummaries.metricKind(forExerciseNamed: exercise.exercise.name) else { return nil }
        return ConsumerProgramSummaries.lastLoggedEntry(entries: priorEntriesByMetric[metric] ?? [], metric: metric, before: startedAt)
    }

    /// This session's factual roll-up (Sets / Duration / lb moved) for the
    /// Workout-complete screen, frozen at `completedAt` once set so the
    /// duration doesn't keep climbing while the client lingers on the
    /// summary.
    public var sessionTotals: ConsumerProgramSummaries.SessionTotals {
        let loggedSets = workout.exercises.flatMap { exercise in
            setLogs(for: exercise).filter(\.logged).map {
                ConsumerProgramSummaries.LoggedSetSummary(weight: Double($0.weightText) ?? 0, reps: Int($0.reps) ?? 0)
            }
        }
        return ConsumerProgramSummaries.sessionTotals(loggedSets: loggedSets, startedAt: startedAt, completedAt: completedAt ?? clock())
    }

    /// The complete-state success card's factual comparison, or `nil` when
    /// no exercise in this workout has both a logged top set and prior
    /// history to compare against (see `ConsumerProgramSummaries.
    /// topSetComparison`).
    public var topSetComparison: ConsumerProgramSummaries.TopSetComparison? {
        var topByExerciseID: [Identifier<ExercisePrescription>: Double] = [:]
        for exercise in workout.exercises {
            let weights = setLogs(for: exercise).filter(\.logged).compactMap { Double($0.weightText) }
            if let top = weights.max() { topByExerciseID[exercise.id] = top }
        }
        return ConsumerProgramSummaries.topSetComparison(
            workout: workout,
            loggedTopWeightByExerciseID: topByExerciseID,
            priorEntriesByMetric: priorEntriesByMetric,
            now: startedAt
        )
    }

    fileprivate static func formattedWeight(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
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
            completedAt = now
            saveErrorMessage = nil
            draftStore.clear()
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
