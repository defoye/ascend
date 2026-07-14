import Domain
import Foundation
import Testing
@testable import Features

@Suite("ProofProfileSummaries")
struct ProofProfileSummariesTests {
    private let professionalID = Identifier<Person>()
    private let clientID = Identifier<Person>()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func engagement(
        _ id: Identifier<Engagement> = Identifier(),
        status: EngagementStatus,
        startedAt: Date?
    ) -> Engagement {
        Engagement(id: id, clientID: clientID, professionalID: professionalID, status: status, startedAt: startedAt, endedAt: nil)
    }

    // MARK: - stats

    @Test("stats counts completed sessions, active engagements, and retention over established engagements only")
    func statsComputesCorrectly() {
        let pending = engagement(status: .pending, startedAt: nil)
        let active1 = engagement(status: .active, startedAt: now.addingTimeInterval(-100 * 86_400))
        let active2 = engagement(status: .active, startedAt: now.addingTimeInterval(-50 * 86_400))
        let paused = engagement(status: .paused, startedAt: now.addingTimeInterval(-80 * 86_400))
        let ended = engagement(status: .ended, startedAt: now.addingTimeInterval(-200 * 86_400))

        let sessions = [
            Session(id: Identifier(), engagementID: active1.id, scheduledAt: now, status: .completed),
            Session(id: Identifier(), engagementID: active1.id, scheduledAt: now, status: .completed),
            Session(id: Identifier(), engagementID: active2.id, scheduledAt: now, status: .completed),
            Session(id: Identifier(), engagementID: active2.id, scheduledAt: now, status: .scheduled),
            Session(id: Identifier(), engagementID: ended.id, scheduledAt: now, status: .cancelled)
        ]

        let stats = ProofProfileSummaries.stats(
            engagements: [pending, active1, active2, paused, ended],
            sessions: sessions
        )

        #expect(stats.sessionsCompleted == 3)
        #expect(stats.activeClients == 2)
        // Established: active1, active2, paused, ended = 4. Non-ended: 3. 3/4 = 0.75.
        #expect(stats.retentionRate == 0.75)
    }

    @Test("retentionRate is nil when there are no established engagements, not a misleading zero")
    func retentionRateNilWhenNoEstablishedEngagements() {
        let pending = engagement(status: .pending, startedAt: nil)
        let stats = ProofProfileSummaries.stats(engagements: [pending], sessions: [])
        #expect(stats.retentionRate == nil)
    }

    @Test("stats on empty input is all zero/nil, not a crash")
    func statsOnEmptyInput() {
        let stats = ProofProfileSummaries.stats(engagements: [], sessions: [])
        #expect(stats == .zero)
    }

    // MARK: - journeys / journeyDescription

    private func derivedOutcome(
        metric: MetricKind = .squat1RM,
        startValue: Double = 185,
        endValue: Double = 225,
        unit: MetricUnit = .lb,
        daysApart: Int = 28,
        endOffsetDays: Int = 0
    ) -> VerifiedOutcome {
        let engagementID = Identifier<Engagement>()
        let end = now.addingTimeInterval(-Double(endOffsetDays) * 86_400)
        let start = end.addingTimeInterval(-Double(daysApart) * 86_400)
        let established = Engagement(
            id: engagementID, clientID: clientID, professionalID: professionalID,
            status: .active, startedAt: start, endedAt: nil
        )
        let progress = [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: startValue, unit: unit),
                recordedAt: start, source: .coachRecorded
            ),
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: endValue, unit: unit),
                recordedAt: end, source: .coachRecorded
            )
        ]
        let session = Session(id: Identifier(), engagementID: engagementID, scheduledAt: end, status: .completed)
        let payment = Payment(
            id: Identifier(), engagementID: engagementID, amountCents: 10_000, currency: "USD",
            status: .succeeded, platformFeeCents: 1_000, stripePaymentIntentID: nil, createdAt: end
        )
        guard let outcome = VerifiedOutcome.derive(
            from: established, metric: metric, progress: progress,
            completedSessions: [session], payments: [payment], clientConsent: true
        ) else {
            fatalError("Test fixture must satisfy all VerifiedOutcome.derive pillars")
        }
        return outcome
    }

    @Test("journeyDescription formats metric, start/end values with a single unit, weeks, and a generic 'Client' subject")
    func journeyDescriptionFormatsExpectedCopy() {
        let outcome = derivedOutcome(metric: .squat1RM, startValue: 185, endValue: 225, unit: .lb, daysApart: 28)
        let description = ProofProfileSummaries.journeyDescription(for: outcome)
        #expect(description == "Client · squat 1RM 185 → 225 lb · 4 weeks")
    }

    @Test("journeyDescription rounds a partial-week duration down but never to zero weeks")
    func journeyDescriptionNeverZeroWeeks() {
        let outcome = derivedOutcome(daysApart: 3)
        let description = ProofProfileSummaries.journeyDescription(for: outcome)
        #expect(description.hasSuffix("1 week"))
    }

    @Test("journey copy never names a client or coach, and never asserts causation (Invariant 2)")
    func journeyCopyAvoidsIdentityAndCausation() {
        let outcome = derivedOutcome()
        let description = ProofProfileSummaries.journeyDescription(for: outcome)

        // No proper-name leakage: description is built purely from
        // metric/value/duration, never a person's display name.
        let forbiddenNameFragments = ["Jordan", "Morgan", "Sam ", "Taylor", "Coach"]
        for fragment in forbiddenNameFragments {
            #expect(!description.contains(fragment))
        }

        // No causal verbs: copy verifies a measured journey, never that the
        // coach caused it.
        let causalPhrases = ["helped", "caused", "made them", "got them", "transformed"]
        for phrase in causalPhrases {
            #expect(!description.lowercased().contains(phrase))
        }

        #expect(description.hasPrefix("Client ·"))
    }

    @Test("journeys sorts most-recently-completed first")
    func journeysSortsNewestFirst() {
        let older = derivedOutcome(daysApart: 60, endOffsetDays: 30)
        let newer = derivedOutcome(daysApart: 10, endOffsetDays: 0)

        let journeys = ProofProfileSummaries.journeys(from: [older, newer])

        #expect(journeys.map(\.id) == [newer.id, older.id])
    }
}
