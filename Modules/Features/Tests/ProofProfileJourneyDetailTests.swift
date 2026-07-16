import DataInterfaces
import Domain
import Foundation
import Testing
@testable import Features

@Suite("ProofProfileCopy / JourneyDetailContent")
struct ProofProfileJourneyDetailTests {
    private let professionalID = Identifier<Person>()
    private let clientID = Identifier<Person>()
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - ProofProfileCopy: the mode → copy mapping (Invariant 2)

    @Test("the .live substantiation line is the verbatim load-bearing copy")
    func liveSubstantiationLineIsVerbatim() {
        #expect(
            ProofProfileCopy.substantiationLine(for: .live)
                == "Backed by a real, paid coaching relationship & tracked measurements."
        )
    }

    @Test("the .free substantiation line is the verbatim load-bearing copy")
    func freeSubstantiationLineIsVerbatim() {
        #expect(
            ProofProfileCopy.substantiationLine(for: .free)
                == "Self-tracked progress over an active coaching relationship."
        )
    }

    @Test("the .free substantiation line never contains the word Verified")
    func freeCopyNeverSaysVerified() {
        #expect(!ProofProfileCopy.substantiationLine(for: .free).contains("Verified"))
    }

    // MARK: - JourneyDetailContent.verified

    private func derivedOutcome(
        metric: MetricKind = .squat1RM,
        startValue: Double = 185,
        endValue: Double = 225,
        unit: MetricUnit = .lb,
        daysApart: Int = 28
    ) -> VerifiedOutcome {
        let engagementID = Identifier<Engagement>()
        let end = now
        let start = end.addingTimeInterval(-Double(daysApart) * 86_400)
        let established = Engagement(
            id: engagementID, clientID: clientID, professionalID: professionalID,
            status: .active, startedAt: start, endedAt: nil
        )
        let progress = [
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: startValue, unit: unit), recordedAt: start, source: .coachRecorded
            ),
            ProgressEntry(
                id: Identifier(), engagementID: engagementID, metric: metric,
                value: MetricValue(value: endValue, unit: unit), recordedAt: end, source: .coachRecorded
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

    @Test("JourneyDetailContent.verified(_:mode: .live) is isVerified and carries the live substantiation line")
    func verifiedContentIsVerifiedInLiveMode() {
        let outcome = derivedOutcome()
        let journey = VerifiedJourney(outcome: outcome, description: ProofProfileSummaries.journeyDescription(for: outcome))
        let content = JourneyDetailContent.verified(journey, mode: .live)

        #expect(content.isVerified)
        #expect(content.substantiationLine == ProofProfileCopy.substantiationLine(for: .live))
        #expect(content.start == outcome.start)
        #expect(content.end == outcome.end)
        #expect(content.startedAt == outcome.startedAt)
        #expect(content.endedAt == outcome.endedAt)
    }

    @Test("JourneyDetailContent.verified never names a client (Invariant 2)")
    func verifiedContentNamesNoClient() {
        let outcome = derivedOutcome()
        let journey = VerifiedJourney(outcome: outcome, description: ProofProfileSummaries.journeyDescription(for: outcome))
        let content = JourneyDetailContent.verified(journey, mode: .live)

        for fragment in ["Jordan", "Morgan", "Sam ", "Taylor", "Coach"] {
            #expect(!content.summaryLine.contains(fragment))
        }
    }

    // MARK: - JourneyDetailContent.tracked

    @Test("JourneyDetailContent.tracked(_:mode: .free) is never isVerified and carries the free substantiation line")
    func trackedContentIsNeverVerified() {
        let engagementID = Identifier<Engagement>()
        let journey = TrackedJourney(
            engagementID: engagementID,
            metric: .bodyweight,
            description: "Client · bodyweight 210 → 196 lb · 8 weeks",
            start: MetricValue(value: 210, unit: .lb),
            end: MetricValue(value: 196, unit: .lb),
            startedAt: now.addingTimeInterval(-56 * 86_400),
            lastRecordedAt: now
        )
        let content = JourneyDetailContent.tracked(journey, mode: .free)

        #expect(!content.isVerified)
        #expect(content.substantiationLine == ProofProfileCopy.substantiationLine(for: .free))
        #expect(!content.substantiationLine.contains("Verified"))
        #expect(content.lowerIsBetter)
    }

    // MARK: - ProofProfileSummaries.journeySummaryLine

    @Test("journeySummaryLine formats category, weeks, a signed delta, and the 'measured' qualifier")
    func journeySummaryLineFormatsExpectedShape() {
        let line = ProofProfileSummaries.journeySummaryLine(
            metric: .squat1RM,
            start: MetricValue(value: 185, unit: .lb),
            end: MetricValue(value: 225, unit: .lb),
            durationDays: 28
        )
        #expect(line == "Client · squat 1RM · 4 weeks · +40 lb, measured")
    }

    @Test("journeySummaryLine uses a minus sign for a decreasing (weight-loss style) delta")
    func journeySummaryLineSignsNegativeDeltas() {
        let line = ProofProfileSummaries.journeySummaryLine(
            metric: .bodyweight,
            start: MetricValue(value: 210, unit: .lb),
            end: MetricValue(value: 196, unit: .lb),
            durationDays: 56
        )
        #expect(line == "Client · bodyweight · 8 weeks · \u{2212}14 lb, measured")
    }

    @Test("journeySummaryLine never names a client or claims causation (Invariant 2)")
    func journeySummaryLineAvoidsIdentityAndCausation() {
        let line = ProofProfileSummaries.journeySummaryLine(
            metric: .squat1RM,
            start: MetricValue(value: 185, unit: .lb),
            end: MetricValue(value: 225, unit: .lb),
            durationDays: 28
        )
        for fragment in ["Jordan", "Morgan", "Sam ", "Taylor", "Coach"] {
            #expect(!line.contains(fragment))
        }
        for phrase in ["helped", "caused", "made them", "got them", "transformed"] {
            #expect(!line.lowercased().contains(phrase))
        }
        #expect(line.hasSuffix(", measured"))
    }
}
