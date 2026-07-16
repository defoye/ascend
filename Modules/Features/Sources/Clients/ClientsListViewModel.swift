import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's client roster: every engagement for a
/// professional, joined with the client's identity/goal and a computed
/// last-activity timestamp, filterable by `EngagementStatus` and searchable
/// by client name.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ClientsListViewModel {
    public private(set) var roster: [ClientRosterItem] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    /// `nil` means "All statuses".
    public var statusFilter: EngagementStatus?
    public var searchText = ""

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
    }

    /// `roster` narrowed by the current status filter and search text.
    public var filteredRoster: [ClientRosterItem] {
        ClientsSummaries.search(ClientsSummaries.filter(roster, status: statusFilter), query: searchText)
    }

    /// Loads and joins every engagement for `professionalID` against its
    /// client's `Person` record and cross-engagement activity sources.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var items: [ClientRosterItem] = []

            for engagement in engagements {
                let client = try await backend.people.get(engagement.clientID)
                let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
                let progress = try await backend.progress.fetchEntries(forEngagement: engagement.id)
                let messages = try await backend.messages.fetchMessages(forEngagement: engagement.id)

                items.append(
                    ClientRosterItem(
                        engagement: engagement,
                        clientName: client?.displayName ?? "Client",
                        primaryGoal: client?.goals.first?.kind,
                        lastActiveAt: ClientsSummaries.lastActivity(sessions: sessions, progress: progress, messages: messages)
                    )
                )
            }

            roster = ClientsSummaries.sortedRoster(items)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your clients. Pull to refresh to try again."
        }
    }
}
