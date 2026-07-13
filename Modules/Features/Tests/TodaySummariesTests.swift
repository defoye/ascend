import Domain
import Foundation
import Testing
@testable import Features

@Suite("TodaySummaries")
struct TodaySummariesTests {
    private let engagementID = Identifier<Engagement>()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("upcomingSessions filters to scheduled, future-or-now sessions, ascending")
    func upcomingSessionsFiltersAndSorts() {
        let farthest = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(2 * 86_400), status: .scheduled)
        let past = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-1 * 86_400), status: .scheduled)
        let wrongStatus = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(86_400), status: .completed)
        let atNow = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now, status: .scheduled)
        let soonest = Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(86_400), status: .scheduled)

        let upcoming = TodaySummaries.upcomingSessions(from: [farthest, past, wrongStatus, atNow, soonest], now: now)

        #expect(upcoming.count == 3)
        #expect(upcoming.map(\.id) == [atNow.id, soonest.id, farthest.id])
        #expect(upcoming.allSatisfy { $0.status == .scheduled && $0.scheduledAt >= now })
    }

    @Test("revenueSummary nets/grosses only succeeded payments within the trailing window")
    func revenueSummaryWindowsAndNetsCorrectly() {
        let inWindow = Payment(
            id: Identifier(), engagementID: engagementID, amountCents: 10_000, currency: "USD",
            status: .succeeded, platformFeeCents: 1_000, stripePaymentIntentID: nil,
            createdAt: now.addingTimeInterval(-10 * 86_400)
        )
        let outsideWindow = Payment(
            id: Identifier(), engagementID: engagementID, amountCents: 5_000, currency: "USD",
            status: .succeeded, platformFeeCents: 500, stripePaymentIntentID: nil,
            createdAt: now.addingTimeInterval(-40 * 86_400)
        )
        let notSucceeded = Payment(
            id: Identifier(), engagementID: engagementID, amountCents: 8_000, currency: "USD",
            status: .pending, platformFeeCents: 800, stripePaymentIntentID: nil,
            createdAt: now.addingTimeInterval(-5 * 86_400)
        )
        let atWindowEdge = Payment(
            id: Identifier(), engagementID: engagementID, amountCents: 3_000, currency: "USD",
            status: .succeeded, platformFeeCents: 300, stripePaymentIntentID: nil,
            createdAt: now.addingTimeInterval(-30 * 86_400)
        )

        let summary = TodaySummaries.revenueSummary(from: [inWindow, outsideWindow, notSucceeded, atWindowEdge], now: now)

        #expect(summary.count == 2)
        #expect(summary.grossCents == 13_000)
        #expect(summary.netCents == 11_700)
    }

    @Test("recentActivity folds progress + client messages across engagements, newest first, capped at limit")
    func recentActivityOrdersAndCaps() {
        let source = EngagementActivity(
            engagementID: engagementID,
            clientName: "Test Client",
            progress: [
                ProgressEntry(
                    id: Identifier(), engagementID: engagementID, metric: .bodyweight,
                    value: MetricValue(value: 180, unit: .lb), recordedAt: now.addingTimeInterval(-1 * 86_400),
                    source: .coachRecorded
                ),
                ProgressEntry(
                    id: Identifier(), engagementID: engagementID, metric: .bodyweight,
                    value: MetricValue(value: 190, unit: .lb), recordedAt: now.addingTimeInterval(-3 * 86_400),
                    source: .coachRecorded
                ),
            ],
            clientMessages: [
                Message(id: Identifier(), engagementID: engagementID, authorID: Identifier(), body: "hi", sentAt: now.addingTimeInterval(-2 * 86_400)),
            ]
        )

        let items = TodaySummaries.recentActivity(from: [source], limit: 2)

        #expect(items.count == 2)
        #expect(items.map(\.occurredAt) == [now.addingTimeInterval(-1 * 86_400), now.addingTimeInterval(-2 * 86_400)])
    }

    @Test("relativeDayLabel buckets Today and Tomorrow independent of the real system clock")
    func relativeDayLabelBuckets() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)

        #expect(TodaySummaries.relativeDayLabel(for: today, now: today, calendar: calendar) == "Today")
        #expect(TodaySummaries.relativeDayLabel(for: today.addingTimeInterval(86_400), now: today, calendar: calendar) == "Tomorrow")
    }
}
