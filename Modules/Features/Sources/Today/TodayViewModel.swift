import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's "Today" dashboard: upcoming sessions, recent
/// client activity, and — while `paymentsMode == .live` — a platform-fee-aware
/// revenue snapshot, aggregated across every engagement of a single
/// professional.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md) — never a
/// concrete backend adapter — so it works unchanged against `InMemoryStore`
/// today and any future adapter. While `paymentsMode == .free` (see
/// docs/BUILD_STATUS.md "Rollout strategy — free first, monetize later"),
/// `revenueSummary` stays `.zero` and no payments are even fetched — there's
/// no live income to imply yet.
@MainActor
@Observable
public final class TodayViewModel {
    public private(set) var upcomingSessions: [UpcomingSession] = []
    public private(set) var recentActivity: [ActivityItem] = []
    /// Stays `.zero` while `paymentsMode == .free`.
    public private(set) var revenueSummary: RevenueSummary = .zero
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    public let paymentsMode: PaymentsMode

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    /// - Parameters:
    ///   - clock: Supplies "now" for upcoming-session filtering and the
    ///     revenue window. Defaults to the real system clock; tests and the
    ///     demo composition root inject a fixed instant instead (see
    ///     `InMemoryStore.referenceDate`).
    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        paymentsMode: PaymentsMode = .live,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.paymentsMode = paymentsMode
        self.clock = clock
    }

    /// Loads and aggregates the dashboard's sections from `backend`.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            let now = clock()

            var upcoming: [UpcomingSession] = []
            var activitySources: [EngagementActivity] = []
            var allPayments: [Payment] = []

            for engagement in engagements {
                let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
                let progress = try await backend.progress.fetchEntries(forEngagement: engagement.id)
                let messages = await firstSnapshot(of: backend.messages.messages(in: engagement.id))
                let client = try await backend.people.get(engagement.clientID)
                let clientName = client?.displayName ?? "Client"

                let engagementUpcoming = TodaySummaries.upcomingSessions(from: sessions, now: now)
                upcoming.append(contentsOf: engagementUpcoming.map { UpcomingSession(session: $0, clientName: clientName) })

                let clientMessages = messages.filter { $0.authorID != professionalID }
                activitySources.append(
                    EngagementActivity(
                        engagementID: engagement.id,
                        clientName: clientName,
                        progress: progress,
                        clientMessages: clientMessages
                    )
                )

                if paymentsMode == .live {
                    allPayments.append(contentsOf: try await backend.payments.payments(forEngagement: engagement.id))
                }
            }

            upcomingSessions = upcoming.sorted { $0.scheduledAt < $1.scheduledAt }
            recentActivity = TodaySummaries.recentActivity(from: activitySources)
            revenueSummary = paymentsMode == .live ? TodaySummaries.revenueSummary(from: allPayments, now: now) : .zero
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your dashboard. Pull to refresh to try again."
        }
    }

    /// `messages(in:)` is a live stream, but the dashboard only needs a
    /// one-shot snapshot: take the first emitted value and stop listening.
    private func firstSnapshot(of stream: AsyncStream<[Message]>) async -> [Message] {
        for await snapshot in stream {
            return snapshot
        }
        return []
    }
}
