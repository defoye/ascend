import Domain
import Foundation
import Testing
@testable import Features

@Suite("TrackedJourneySummaries")
struct TrackedJourneySummariesTests {
    private let professionalID = Identifier<Person>()
    private let clientID = Identifier<Person>()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func engagement(
        _ id: Identifier<Engagement> = Identifier(),
        status: EngagementStatus = .active,
        startedAt: Date? = nil
    ) -> Engagement {
        Engagement(
            id: id,
            clientID: clientID,
            professionalID: professionalID,
            status: status,
            startedAt: startedAt ?? now.addingTimeInterval(-100 * 86_400),
            endedAt: nil
        )
    }

    private func progressPoints(
        engagementID: Identifier<Engagement>,
        metric: MetricKind = .squat1RM,
        startValue: Double = 185,
        endValue: Double = 225,
        unit: MetricUnit = .lb,
        daysApart: Int = 28,
        endOffsetDays: Int = 0
    ) -> [ProgressEntry] {
        let end = now.addingTimeInterval(-Double(endOffsetDays) * 86_400)
        let start = end.addingTimeInterval(-Double(daysApart) * 86_400)
        return [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: startValue, unit: unit), recordedAt: start, source: .coachRecorded
            ),
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: endValue, unit: unit), recordedAt: end, source: .coachRecorded
            )
        ]
    }

    private func completedSession(engagementID: Identifier<Engagement>, at date: Date? = nil) -> Session {
        Session(id: Identifier(), engagementID: engagementID, scheduledAt: date ?? now, status: .completed)
    }

    // MARK: - Non-payment pillars mirror VerifiedOutcome.derive

    @Test("every non-payment pillar satisfied yields a TrackedJourney, with no notion of payment at all")
    func fullyQualifyingEvidenceYieldsTrackedJourney() {
        let engagementID = Identifier<Engagement>()
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: progressPoints(engagementID: engagementID),
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        let journeys = TrackedJourneySummaries.trackedJourneys(from: [evidence])

        #expect(journeys.count == 1)
        #expect(journeys.first?.engagementID == engagementID)
        #expect(journeys.first?.metric == .squat1RM)
        #expect(journeys.first?.description == "Client · squat 1RM 185 → 225 lb · 4 weeks")
        // The first/last time-separated points this journey was derived
        // from are exposed directly, honestly, alongside the description —
        // never fabricated, and never more than the two points the
        // qualifying evidence actually carried.
        #expect(journeys.first?.start == MetricValue(value: 185, unit: .lb))
        #expect(journeys.first?.end == MetricValue(value: 225, unit: .lb))
        #expect(journeys.first?.startedAt != nil)
    }

    @Test("an unestablished engagement yields zero Tracked journeys even with otherwise-qualifying evidence")
    func unestablishedEngagementYieldsNothing() {
        let engagementID = Identifier<Engagement>()
        let pending = Engagement(
            id: engagementID, clientID: clientID, professionalID: professionalID,
            status: .pending, startedAt: nil, endedAt: nil
        )
        let evidence = TrackedEngagementEvidence(
            engagement: pending,
            progress: progressPoints(engagementID: engagementID),
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        #expect(TrackedJourneySummaries.trackedJourneys(from: [evidence]).isEmpty)
    }

    @Test("zero completed sessions yields zero Tracked journeys")
    func noCompletedSessionsYieldsNothing() {
        let engagementID = Identifier<Engagement>()
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: progressPoints(engagementID: engagementID),
            completedSessions: [],
            clientConsent: true
        )

        #expect(TrackedJourneySummaries.trackedJourneys(from: [evidence]).isEmpty)
    }

    @Test("consent withheld yields zero Tracked journeys, even though every other pillar is satisfied — Tracked is never a consent bypass")
    func consentOffYieldsNothing() {
        let engagementID = Identifier<Engagement>()
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: progressPoints(engagementID: engagementID),
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: false
        )

        #expect(TrackedJourneySummaries.trackedJourneys(from: [evidence]).isEmpty)
    }

    @Test("fewer than two time-separated progress points yields zero Tracked journeys for that metric")
    func insufficientProgressPointsYieldsNothing() {
        let engagementID = Identifier<Engagement>()
        let onlyOnePoint = Array(progressPoints(engagementID: engagementID).prefix(1))
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: onlyOnePoint,
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        #expect(TrackedJourneySummaries.trackedJourneys(from: [evidence]).isEmpty)
    }

    @Test("two progress points recorded at the exact same timestamp don't count as time-separated")
    func sameTimestampPointsDoNotQualify() {
        let engagementID = Identifier<Engagement>()
        let sameInstant = now
        let progress = [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: .squat1RM,
                value: MetricValue(value: 185, unit: .lb), recordedAt: sameInstant, source: .coachRecorded
            ),
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: .squat1RM,
                value: MetricValue(value: 225, unit: .lb), recordedAt: sameInstant, source: .coachRecorded
            )
        ]
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: progress,
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        #expect(TrackedJourneySummaries.trackedJourneys(from: [evidence]).isEmpty)
    }

    @Test("one TrackedJourney per metric with qualifying progress, independently gated")
    func onePerQualifyingMetric() {
        let engagementID = Identifier<Engagement>()
        let squatProgress = progressPoints(engagementID: engagementID, metric: .squat1RM)
        // Bodyweight only has a single point — doesn't qualify on its own.
        let bodyweightSinglePoint = [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: .bodyweight,
                value: MetricValue(value: 180, unit: .lb), recordedAt: now, source: .coachRecorded
            )
        ]
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: squatProgress + bodyweightSinglePoint,
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        let journeys = TrackedJourneySummaries.trackedJourneys(from: [evidence])
        #expect(journeys.count == 1)
        #expect(journeys.first?.metric == .squat1RM)
    }

    // MARK: - Aggregation / sorting across engagements

    @Test("trackedJourneys(from:) sorts most-recently-measured first across engagements")
    func sortsNewestFirstAcrossEngagements() {
        let olderEngagementID = Identifier<Engagement>()
        let newerEngagementID = Identifier<Engagement>()

        let olderEvidence = TrackedEngagementEvidence(
            engagement: engagement(olderEngagementID),
            progress: progressPoints(engagementID: olderEngagementID, daysApart: 60, endOffsetDays: 30),
            completedSessions: [completedSession(engagementID: olderEngagementID)],
            clientConsent: true
        )
        let newerEvidence = TrackedEngagementEvidence(
            engagement: engagement(newerEngagementID),
            progress: progressPoints(engagementID: newerEngagementID, daysApart: 10, endOffsetDays: 0),
            completedSessions: [completedSession(engagementID: newerEngagementID)],
            clientConsent: true
        )

        let journeys = TrackedJourneySummaries.trackedJourneys(from: [olderEvidence, newerEvidence])

        #expect(journeys.map(\.engagementID) == [newerEngagementID, olderEngagementID])
    }

    @Test("empty evidence yields an empty result, not a crash")
    func emptyEvidenceYieldsEmpty() {
        #expect(TrackedJourneySummaries.trackedJourneys(from: []).isEmpty)
    }

    // MARK: - Description matches ProofProfileSummaries' phrasing exactly

    @Test("TrackedJourney description is identical to ProofProfileSummaries.journeyDescription(for:) given the same metric/values/duration")
    func descriptionMatchesVerifiedPhrasing() throws {
        let engagementID = Identifier<Engagement>()
        let progress = progressPoints(engagementID: engagementID, metric: .fiveKTime, startValue: 1_500, endValue: 1_400, unit: .seconds, daysApart: 21)
        let evidence = TrackedEngagementEvidence(
            engagement: engagement(engagementID),
            progress: progress,
            completedSessions: [completedSession(engagementID: engagementID)],
            clientConsent: true
        )

        let tracked = try #require(TrackedJourneySummaries.trackedJourneys(from: [evidence]).first)
        let expectedDescription = ProofProfileSummaries.journeyDescription(
            metric: .fiveKTime,
            start: MetricValue(value: 1_500, unit: .seconds),
            end: MetricValue(value: 1_400, unit: .seconds),
            durationDays: 21
        )
        #expect(tracked.description == expectedDescription)
    }
}
