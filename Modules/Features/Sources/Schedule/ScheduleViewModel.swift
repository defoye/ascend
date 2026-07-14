import DataInterfaces
import Domain
import Foundation
import Observation

/// A client engagement the coach can book a new session against, paired
/// with the client's display name.
public struct BookableEngagement: Sendable, Identifiable, Equatable {
    public let engagementID: Identifier<Engagement>
    public let clientName: String

    public init(engagementID: Identifier<Engagement>, clientName: String) {
        self.engagementID = engagementID
        self.clientName = clientName
    }

    public var id: Identifier<Engagement> { engagementID }
}

/// View model for the coach's schedule: every session across every
/// engagement for a professional, viewable by day or week, navigable
/// forward/back, with per-session lifecycle actions (complete/cancel/
/// no-show) and the coach's weekly availability windows for context.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md) plus a clock and
/// an injected `SessionReminderScheduling` — never a concrete backend
/// adapter or `UNUserNotificationCenter` directly.
@MainActor
@Observable
public final class ScheduleViewModel {
    public private(set) var allSessions: [ScheduledSession] = []
    public private(set) var bookableEngagements: [BookableEngagement] = []
    public private(set) var availabilityWindows: [AvailabilityWindow] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?
    public private(set) var actionErrorMessage: String?

    public var viewMode: ScheduleViewMode = .day
    /// The date the day/week view is currently centered on. Defaults to
    /// `clock()` so the schedule opens on "now".
    public var referenceDate: Date

    /// Exposed (rather than kept private) so the view can construct sibling
    /// view models that need the same backend/identifiers — e.g.
    /// `BookSessionViewModel` and `AvailabilityViewModel`.
    public let backend: any Backend
    public let professionalID: Identifier<Person>
    let clock: @Sendable () -> Date
    private let reminders: any SessionReminderScheduling
    private var hasRequestedReminderAuthorization = false

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        reminders: any SessionReminderScheduling = LiveSessionReminderScheduler()
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
        self.reminders = reminders
        referenceDate = clock()
    }

    /// The sessions in the currently-displayed day or week, grouped by day.
    public var groupedDisplayedSessions: [ScheduleSummaries.DayGroup] {
        ScheduleSummaries.groupedByDay(displayedSessions)
    }

    public var displayedSessions: [ScheduledSession] {
        switch viewMode {
        case .day: ScheduleSummaries.sessions(allSessions, on: referenceDate)
        case .week: ScheduleSummaries.sessions(allSessions, inWeekContaining: referenceDate)
        }
    }

    /// The availability windows relevant to the currently-displayed day (day
    /// mode) or every window touched by the displayed week (week mode).
    public var displayedAvailabilityWindows: [AvailabilityWindow] {
        switch viewMode {
        case .day:
            ScheduleSummaries.windows(availabilityWindows, on: referenceDate)
        case .week:
            availabilityWindows.sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
        }
    }

    // MARK: - Navigation

    public func goToToday() {
        referenceDate = clock()
    }

    public func goForward() {
        referenceDate = viewMode == .day
            ? ScheduleSummaries.nextDay(from: referenceDate)
            : ScheduleSummaries.nextWeek(from: referenceDate)
    }

    public func goBackward() {
        referenceDate = viewMode == .day
            ? ScheduleSummaries.previousDay(from: referenceDate)
            : ScheduleSummaries.previousWeek(from: referenceDate)
    }

    // MARK: - Loading

    /// Loads every session and availability window for the professional,
    /// aggregated across all their engagements, and requests notification
    /// authorization the first time the schedule is shown.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        if !hasRequestedReminderAuthorization {
            hasRequestedReminderAuthorization = true
            _ = await reminders.requestAuthorization()
        }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var sessions: [ScheduledSession] = []
            var bookable: [BookableEngagement] = []

            for engagement in engagements {
                let client = try await backend.people.get(engagement.clientID)
                let clientName = client?.displayName ?? "Client"
                let engagementSessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
                sessions.append(contentsOf: engagementSessions.map { ScheduledSession(session: $0, clientName: clientName) })

                if engagement.status != .ended && engagement.status != .completed {
                    bookable.append(BookableEngagement(engagementID: engagement.id, clientName: clientName))
                }
            }

            allSessions = sessions.sorted { $0.scheduledAt < $1.scheduledAt }
            bookableEngagements = bookable.sorted { $0.clientName.localizedCaseInsensitiveCompare($1.clientName) == .orderedAscending }
            availabilityWindows = try await backend.availability.windows(forProfessional: professionalID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your schedule. Pull to refresh to try again."
        }
    }

    // MARK: - Lifecycle transitions

    public func complete(_ scheduled: ScheduledSession) async {
        await transition(scheduled, to: .completed)
    }

    public func cancel(_ scheduled: ScheduledSession) async {
        await transition(scheduled, to: .cancelled)
    }

    public func markNoShow(_ scheduled: ScheduledSession) async {
        await transition(scheduled, to: .noShow)
    }

    /// Builds a fresh `Session` (Domain structs are immutable) with the new
    /// status and persists it via `SessionRepository.upsert(_:)`, only if
    /// `SessionTransitions` allows the move. Cancelling also removes any
    /// pending reminder for the session.
    private func transition(_ scheduled: ScheduledSession, to newStatus: SessionStatus) async {
        guard SessionTransitions.canTransition(from: scheduled.status, to: newStatus) else { return }
        let updated = Session(
            id: scheduled.session.id,
            engagementID: scheduled.engagementID,
            scheduledAt: scheduled.scheduledAt,
            status: newStatus
        )
        do {
            _ = try await backend.sessions.upsert(updated)
            if newStatus == .cancelled {
                await reminders.cancelReminder(for: updated.id)
            }
            actionErrorMessage = nil
            await load()
        } catch {
            actionErrorMessage = "Couldn't update this session. Try again."
        }
    }
}
