import Domain
import Foundation
import Testing
@testable import Features

@Suite("ClientsSummaries")
struct ClientsSummariesTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("lastActivity returns the max timestamp across sessions/progress/messages, or nil when empty")
    func lastActivityComputesMax() {
        let engagementID = Identifier<Engagement>()
        let sessions = [
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-2 * 86_400), status: .completed)
        ]
        let progress = [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: .bodyweight,
                value: MetricValue(value: 180, unit: .lb), recordedAt: now, source: .coachRecorded
            )
        ]
        let messages = [
            Message(id: Identifier(), engagementID: engagementID, authorID: Identifier(), body: "hi", sentAt: now.addingTimeInterval(-1 * 86_400))
        ]

        #expect(ClientsSummaries.lastActivity(sessions: sessions, progress: progress, messages: messages) == now)
        #expect(ClientsSummaries.lastActivity(sessions: [], progress: [], messages: []) == nil)
    }

    @Test("filter narrows to a single status, and nil returns everything")
    func filterByStatus() {
        let active = makeItem(status: .active, name: "Alex")
        let paused = makeItem(status: .paused, name: "Bailey")
        let items = [active, paused]

        #expect(ClientsSummaries.filter(items, status: .active) == [active])
        #expect(ClientsSummaries.filter(items, status: nil) == items)
    }

    @Test("search is case-insensitive and substring-based; a blank query returns everything")
    func searchByName() {
        let alex = makeItem(status: .active, name: "Alex Rivera")
        let bailey = makeItem(status: .active, name: "Bailey Chen")
        let items = [alex, bailey]

        #expect(ClientsSummaries.search(items, query: "rivera") == [alex])
        #expect(ClientsSummaries.search(items, query: "  ") == items)
    }

    @Test("sortedRoster orders active-first, then alphabetically within a status group")
    func sortedRosterOrders() {
        let zed = makeItem(status: .active, name: "Zed")
        let anna = makeItem(status: .active, name: "Anna")
        let paused = makeItem(status: .paused, name: "Aaa")

        let sorted = ClientsSummaries.sortedRoster([paused, zed, anna])

        #expect(sorted.map(\.clientName) == ["Anna", "Zed", "Aaa"])
    }

    @Test("sessionRetention is the fraction of elapsed weeks with a completed session")
    func sessionRetentionComputesFraction() {
        // A fixed ISO8601/UTC calendar so week boundaries are deterministic
        // regardless of the test machine's locale/timezone.
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Both Tuesdays, exactly 3 whole weeks apart.
        let start = now.addingTimeInterval(-3 * 7 * 86_400)
        // Two sessions a few hours apart on `start`'s own day — guaranteed
        // to land in the same calendar week regardless of week-start
        // convention, so `weeksWithSession` is unambiguously 1.
        let completed = [start.addingTimeInterval(2 * 3_600), start.addingTimeInterval(5 * 3_600)]

        let retention = ClientsSummaries.sessionRetention(completedSessionDates: completed, since: start, now: now, calendar: calendar)

        #expect(retention?.elapsedWeeks == 4)
        #expect(retention?.weeksWithSession == 1)
        #expect(retention?.percent == 25)
    }

    @Test("sessionRetention is nil with no completed sessions or a future start date, never a fabricated number")
    func sessionRetentionNilWhenUnmeasurable() {
        #expect(ClientsSummaries.sessionRetention(completedSessionDates: [], since: now.addingTimeInterval(-86_400), now: now) == nil)
        #expect(
            ClientsSummaries.sessionRetention(completedSessionDates: [now], since: now.addingTimeInterval(86_400), now: now) == nil
        )
    }

    private func makeItem(status: EngagementStatus, name: String) -> ClientRosterItem {
        ClientRosterItem(
            engagement: Engagement(
                id: Identifier(), clientID: Identifier(), professionalID: Identifier(),
                status: status, startedAt: now, endedAt: nil
            ),
            clientName: name,
            primaryGoal: nil,
            lastActiveAt: nil
        )
    }
}
