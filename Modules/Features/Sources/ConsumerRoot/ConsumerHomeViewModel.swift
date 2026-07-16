import DataInterfaces
import DesignSystem
import Domain
import Foundation
import Observation

/// View model for the client's "Today" dashboard: today's assigned workout
/// (from the program assigned to this client's engagement), the next
/// upcoming session, and a nudge — the most recent message from their
/// coach.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md). Mirrors the
/// coach `TodayViewModel`'s one-shot load idiom.
@MainActor
@Observable
public final class ConsumerHomeViewModel {
    public private(set) var clientName = "You"
    public private(set) var engagement: Engagement?
    public private(set) var coachName = "Your coach"
    public private(set) var programTitle: String?
    public private(set) var currentWorkout: ConsumerProgramSummaries.CurrentWorkout?
    public private(set) var nextSession: Session?
    public private(set) var coachNudge: Message?
    public private(set) var bodyweightPoints: [ProgressPoint] = []
    public private(set) var bodyweightUnit = "lb"
    public private(set) var weeklySessionSummary: ConsumerProgramSummaries.WeeklySessionSummary?
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    public let backend: any Backend
    public let clientID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(backend: any Backend, clientID: Identifier<Person>, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.backend = backend
        self.clientID = clientID
        self.clock = clock
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            clientName = try await backend.people.get(clientID)?.displayName ?? clientName

            let engagements = try await backend.engagements.fetchEngagements(forClient: clientID)
            let chosen = ConsumerProgramSummaries.primaryEngagement(engagements)
            engagement = chosen
            loadErrorMessage = nil

            guard let chosen else {
                clearDerivedState()
                return
            }

            coachName = try await backend.people.get(chosen.professionalID)?.displayName ?? "Your coach"
            await loadCurrentWorkout(for: chosen)

            let sessions = try await backend.sessions.fetchSessions(forEngagement: chosen.id)
            nextSession = TodaySummaries.upcomingSessions(from: sessions, now: clock()).first
            weeklySessionSummary = ConsumerProgramSummaries.weeklySessionSummary(sessions: sessions, now: clock())

            let messages = try await backend.messages.fetchMessages(forEngagement: chosen.id)
            coachNudge = messages
                .filter { $0.authorID == chosen.professionalID }
                .max { $0.sentAt < $1.sentAt }

            await loadBodyweight(for: chosen)
        } catch {
            loadErrorMessage = "Couldn't load your dashboard. Pull to refresh to try again."
        }
    }

    private func loadCurrentWorkout(for engagement: Engagement) async {
        guard
            let assignments = try? await backend.programs.assignments(forEngagement: engagement.id),
            let latestAssignment = assignments.sorted(by: { $0.assignedAt > $1.assignedAt }).first,
            let program = try? await backend.programs.get(latestAssignment.programID)
        else {
            programTitle = nil
            currentWorkout = nil
            return
        }
        programTitle = program.title
        currentWorkout = ConsumerProgramSummaries.currentWorkout(program: program, startDate: latestAssignment.startDate, now: clock())
    }

    /// Additive load: the client's own bodyweight history for the "Today"
    /// dashboard's chart, mirroring how `ProgressViewModel` fetches an
    /// engagement's entries. Real measurements only — never a fabricated
    /// series when the client hasn't logged any yet.
    private func loadBodyweight(for engagement: Engagement) async {
        let entries = (try? await backend.progress.fetchEntries(forEngagement: engagement.id, metric: .bodyweight)) ?? []
        let sorted = entries.sorted { $0.recordedAt < $1.recordedAt }
        bodyweightPoints = sorted.map { ProgressPoint(date: $0.recordedAt, value: $0.value.value) }
        bodyweightUnit = sorted.last?.value.unit.shortLabel ?? bodyweightUnit
    }

    private func clearDerivedState() {
        coachName = "Your coach"
        programTitle = nil
        currentWorkout = nil
        nextSession = nil
        coachNudge = nil
        bodyweightPoints = []
        weeklySessionSummary = nil
    }
}
