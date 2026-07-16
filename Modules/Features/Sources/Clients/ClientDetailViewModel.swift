import DataInterfaces
import DesignSystem
import Domain
import Foundation
import Observation

/// View model for a single client's detail screen: the engagement's header
/// info, goals, per-metric progress, assigned program summary, and coach
/// notes — plus the write-back actions (status change, note add/edit) each
/// section supports.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ClientDetailViewModel {
    public private(set) var engagement: Engagement?
    public private(set) var client: Person?
    public private(set) var program: Program?
    public private(set) var progressEntries: [ProgressEntry] = []
    public private(set) var notes: [CoachNote] = []
    public private(set) var sessions: [Session] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    /// Bound to the "add a note" text field.
    public var draftNoteBody = ""

    /// Exposed (rather than kept private) so the view can construct sibling
    /// view models that need the same backend/identifiers — e.g.
    /// `AssignProgramViewModel` for the "Assign / Reassign program" action.
    public let backend: any Backend
    public let engagementID: Identifier<Engagement>
    public let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        engagementID: Identifier<Engagement>,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.engagementID = engagementID
        self.professionalID = professionalID
        self.clock = clock
    }

    public var clientName: String { client?.displayName ?? "Client" }
    public var goals: [Goal] { client?.goals ?? [] }

    /// Distinct metrics the client has progress entries for, ordered by
    /// first-logged date.
    public var trackedMetrics: [MetricKind] {
        var seen: Set<MetricKind> = []
        var ordered: [MetricKind] = []
        for entry in progressEntries.sorted(by: { $0.recordedAt < $1.recordedAt }) where seen.insert(entry.metric).inserted {
            ordered.append(entry.metric)
        }
        return ordered
    }

    /// Chart-ready points for a single metric, oldest first.
    public func points(for metric: MetricKind) -> [ProgressPoint] {
        progressEntries
            .filter { $0.metric == metric }
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { ProgressPoint(date: $0.recordedAt, value: $0.value.value) }
    }

    /// Count of `.completed` sessions, for the "Sessions" stat tile (see
    /// docs/design/handoff/HANDOFF_README.md §02).
    public var completedSessionsCount: Int {
        sessions.filter { $0.status == .completed }.count
    }

    /// How consistently the client has kept up completed sessions since the
    /// engagement started, for the "Retention" stat tile. `nil` (rendered as
    /// "—") when there's no completed session or start date to measure from.
    public var sessionRetention: ClientsSummaries.SessionRetention? {
        guard let start = engagement?.startedAt else { return nil }
        let completedDates = sessions.filter { $0.status == .completed }.map(\.scheduledAt)
        return ClientsSummaries.sessionRetention(completedSessionDates: completedDates, since: start, now: clock())
    }

    /// Loads the engagement, client, assigned program (most recently
    /// assigned, if more than one), progress entries, and coach notes.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagement = try await backend.engagements.get(engagementID)
            self.engagement = engagement
            if let engagement {
                client = try await backend.people.get(engagement.clientID)
            }

            let assignments = try await backend.programs.assignments(forEngagement: engagementID)
            if let latestAssignment = assignments.sorted(by: { $0.assignedAt > $1.assignedAt }).first {
                program = try await backend.programs.get(latestAssignment.programID)
            } else {
                program = nil
            }

            progressEntries = try await backend.progress.fetchEntries(forEngagement: engagementID)
            notes = try await backend.notes.notes(forEngagement: engagementID)
            sessions = try await backend.sessions.fetchSessions(forEngagement: engagementID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load this client. Pull to refresh to try again."
        }
    }

    /// Writes a new engagement status back through `EngagementRepository`.
    /// `Engagement` is immutable, so this builds a fresh value from the
    /// current one with only `status` (and, if the relationship is starting
    /// for the first time, `startedAt`) changed.
    public func setStatus(_ status: EngagementStatus) async {
        guard let current = engagement else { return }
        let updated = Engagement(
            id: current.id,
            clientID: current.clientID,
            professionalID: current.professionalID,
            status: status,
            startedAt: current.startedAt ?? (status == .pending ? nil : clock()),
            endedAt: current.endedAt
        )
        do {
            engagement = try await backend.engagements.upsert(updated)
        } catch {
            loadErrorMessage = "Couldn't update status. Try again."
        }
    }

    /// Persists `draftNoteBody` as a new `CoachNote` and clears the draft.
    public func saveNote() async {
        let trimmed = draftNoteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = clock()
        let note = CoachNote(
            id: Identifier(),
            engagementID: engagementID,
            authorID: professionalID,
            body: trimmed,
            createdAt: now,
            updatedAt: now
        )
        do {
            let saved = try await backend.notes.upsert(note)
            notes.append(saved)
            notes.sort { $0.createdAt < $1.createdAt }
            draftNoteBody = ""
        } catch {
            loadErrorMessage = "Couldn't save your note. Try again."
        }
    }

    /// Rewrites an existing note's body, preserving its `createdAt` but
    /// bumping `updatedAt`.
    public func updateNote(_ note: CoachNote, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let updated = CoachNote(
            id: note.id,
            engagementID: note.engagementID,
            authorID: note.authorID,
            body: trimmed,
            createdAt: note.createdAt,
            updatedAt: clock()
        )
        do {
            let saved = try await backend.notes.upsert(updated)
            if let index = notes.firstIndex(where: { $0.id == saved.id }) {
                notes[index] = saved
            }
        } catch {
            loadErrorMessage = "Couldn't update your note. Try again."
        }
    }
}
