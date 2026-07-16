import Domain
import Foundation

/// A snapshot of an in-progress `WorkoutPlayerViewModel`'s local UI state,
/// captured so a killed/backgrounded-and-evicted app can restore a
/// mid-workout session instead of handing the client back a blank player.
/// See `WorkoutPlayerViewModel`'s header doc comment for what does and
/// doesn't persist, and why.
///
/// Named `WorkoutSessionDraft`, not `WorkoutDraft`, because `Features`
/// already has a public `WorkoutDraft` (`Programs/ProgramDraft.swift`, the
/// program-builder's editable draft of a `Workout`'s shape) — an unrelated
/// concept that happens to share the obvious name.
public struct WorkoutSessionDraft: Codable, Sendable, Equatable {
    public let engagementID: Identifier<Engagement>
    public let workoutID: Identifier<Workout>
    public let startedAt: Date
    public let bodyweightText: String
    public let setLogsByExercise: [Identifier<ExercisePrescription>: [WorkoutPlayerViewModel.SetLog]]
    public let savedAt: Date

    public init(
        engagementID: Identifier<Engagement>,
        workoutID: Identifier<Workout>,
        startedAt: Date,
        bodyweightText: String,
        setLogsByExercise: [Identifier<ExercisePrescription>: [WorkoutPlayerViewModel.SetLog]],
        savedAt: Date
    ) {
        self.engagementID = engagementID
        self.workoutID = workoutID
        self.startedAt = startedAt
        self.bodyweightText = bodyweightText
        self.setLogsByExercise = setLogsByExercise
        self.savedAt = savedAt
    }
}

/// A mockable seam over local draft persistence, so `WorkoutPlayerViewModel`
/// logic stays testable without ever touching the filesystem in unit tests
/// (see docs/TESTING.md) — the same shape as `SessionReminderScheduling`.
///
/// Deliberately a single current draft, not a keyed collection: only one
/// workout is realistically in flight on a device at a time, and the
/// view-model's restore gate (matching engagement, workout, and day) already
/// discards a draft that doesn't apply — a keyed store would add complexity
/// with no real benefit over "the most recent in-progress workout, if any."
public protocol WorkoutSessionDraftStoring: Sendable {
    /// Overwrites the current draft.
    func save(_ draft: WorkoutSessionDraft)

    /// The current draft, if any — `nil` when there's none or it couldn't be
    /// read.
    func load() -> WorkoutSessionDraft?

    /// Discards the current draft (e.g. after a successful completion, or
    /// when a loaded draft no longer applies).
    func clear()
}

/// The real `WorkoutSessionDraftStoring` implementation, backed by a JSON
/// file in Application Support. Mirrors `OfflineWriteQueue`'s persistence
/// idiom: atomic writes, best-effort silent failure on both the
/// directory-creation step and the write itself — in-memory state (the view
/// model's own `setLogsByExercise`, etc.) still functions for the rest of
/// this process lifetime even if disk I/O fails, so a persistence failure
/// here degrades gracefully rather than crashing or blocking the workout.
///
/// This is composition-root-shaped state (like the App target's
/// `RolePresenceStore`), but it's scoped entirely to one feature's screen, so
/// it lives here in `Features` behind this protocol with an injectable
/// storage seam instead — exactly the same call `SessionReminderScheduling`/
/// `LiveSessionReminderScheduler` made for local notifications. That keeps
/// it inside the `Features -> DesignSystem, DataInterfaces, Domain`
/// dependency rule (it only needs `Foundation`, a system framework, not a
/// concrete backend adapter) rather than forcing this feature-local concern
/// up into the App target.
public struct LiveWorkoutSessionDraftStore: WorkoutSessionDraftStoring {
    private let fileURL: URL

    public init(directory: URL = LiveWorkoutSessionDraftStore.defaultDirectory()) {
        self.fileURL = directory.appendingPathComponent("workout-draft.json")
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Ascend", isDirectory: true)
    }

    public func save(_ draft: WorkoutSessionDraft) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(draft)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence: the view model's in-memory state still
            // functions for the rest of this process lifetime even if disk
            // I/O fails.
        }
    }

    public func load() -> WorkoutSessionDraft? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(WorkoutSessionDraft.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
