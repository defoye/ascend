import Foundation
import Testing
@testable import Domain

@Suite("VerifiedOutcome.derive")
struct VerifiedOutcomeDeriveTests {
    // MARK: - Fixtures

    private static let clientID = Identifier<Person>()
    private static let professionalID = Identifier<Person>()
    private static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEngagement(
        status: EngagementStatus = .active,
        startedAt: Date? = VerifiedOutcomeDeriveTests.referenceDate,
        endedAt: Date? = nil
    ) -> Engagement {
        Engagement(
            id: Identifier(),
            clientID: Self.clientID,
            professionalID: Self.professionalID,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    private func makeCompletedSession(engagementID: Identifier<Engagement>) -> Session {
        Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.referenceDate, status: .completed)
    }

    private func makeSucceededPayment(engagementID: Identifier<Engagement>) -> Payment {
        Payment(
            id: Identifier(),
            engagementID: engagementID,
            amountCents: 10_000,
            currency: "USD",
            status: .succeeded,
            platformFeeCents: 1_000,
            stripePaymentIntentID: "pi_test"
        )
    }

    private func progressEntry(
        engagementID: Identifier<Engagement>,
        metric: MetricKind,
        value: Double,
        unit: MetricUnit,
        daysAfterReference: Int
    ) -> ProgressEntry {
        ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: Self.referenceDate.addingTimeInterval(Double(daysAfterReference) * 86_400),
            source: .coachRecorded
        )
    }

    // MARK: - Structural guarantee

    @Test("VerifiedOutcome can only be constructed via derive; the memberwise init is private")
    func verifiedOutcomeHasNoPublicInitializer() {
        // NOTE: `VerifiedOutcome(id:engagementID:metric:start:end:startedAt:endedAt:basis:)`
        // does not compile from this call site (or anywhere outside VerifiedOutcome.swift)
        // because the memberwise initializer is declared `private`. That is the
        // structural enforcement of Invariant 1 (docs/PRODUCT.md): the only way to
        // obtain an instance is the `derive` factory below.
        let engagement = makeEngagement()
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome != nil)
    }

    // MARK: - Missing-pillar tests: each returns nil

    @Test("nil when the relationship is still pending")
    func nilWhenEngagementPending() {
        let engagement = makeEngagement(status: .pending, startedAt: Self.referenceDate)
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    @Test("nil when the relationship has no start date")
    func nilWhenEngagementHasNoStartDate() {
        let engagement = makeEngagement(status: .active, startedAt: nil)
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    @Test("nil when there is no completed session")
    func nilWhenNoCompletedSession() {
        let engagement = makeEngagement()
        let scheduledOnly = Session(
            id: Identifier(),
            engagementID: engagement.id,
            scheduledAt: Self.referenceDate,
            status: .scheduled
        )
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [scheduledOnly],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    @Test("nil when there is no succeeded payment")
    func nilWhenNoSucceededPayment() {
        let engagement = makeEngagement()
        let pendingPayment = Payment(
            id: Identifier(),
            engagementID: engagement.id,
            amountCents: 10_000,
            currency: "USD",
            status: .pending,
            platformFeeCents: 1_000,
            stripePaymentIntentID: nil
        )
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [pendingPayment],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    @Test("nil when client consent is not granted")
    func nilWhenConsentNotGranted() {
        let engagement = makeEngagement()
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 190, unit: .lb, daysAfterReference: 30),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: false
        )

        #expect(outcome == nil)
    }

    @Test("nil when there is only a single progress point")
    func nilWhenOnlyOneProgressPoint() {
        let engagement = makeEngagement()
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [
                progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
            ],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    @Test("nil when two progress points share the same recordedAt timestamp")
    func nilWhenProgressPointsAreNotTimeSeparated() {
        let engagement = makeEngagement()
        let sameInstant = Self.referenceDate
        let pointA = ProgressEntry(
            id: Identifier(),
            engagementID: engagement.id,
            metric: .bodyweight,
            value: MetricValue(value: 200, unit: .lb),
            recordedAt: sameInstant,
            source: .coachRecorded
        )
        let pointB = ProgressEntry(
            id: Identifier(),
            engagementID: engagement.id,
            metric: .bodyweight,
            value: MetricValue(value: 190, unit: .lb),
            recordedAt: sameInstant,
            source: .coachRecorded
        )

        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: [pointA, pointB],
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }

    // MARK: - Happy path

    @Test("happy path: lower-is-better metric (fiveKTime) computed correctly, sorted by recordedAt")
    func happyPathLowerIsBetterMetric() throws {
        let engagement = makeEngagement()
        // Fed out of order to prove derive sorts by recordedAt rather than trusting input order.
        let progress = [
            progressEntry(engagementID: engagement.id, metric: .fiveKTime, value: 1_500, unit: .seconds, daysAfterReference: 60),
            progressEntry(engagementID: engagement.id, metric: .fiveKTime, value: 1_620, unit: .seconds, daysAfterReference: 0),
            progressEntry(engagementID: engagement.id, metric: .fiveKTime, value: 1_560, unit: .seconds, daysAfterReference: 30),
        ]

        let outcome = try #require(
            VerifiedOutcome.derive(
                from: engagement,
                metric: .fiveKTime,
                progress: progress,
                completedSessions: [makeCompletedSession(engagementID: engagement.id)],
                payments: [makeSucceededPayment(engagementID: engagement.id)],
                clientConsent: true
            )
        )

        #expect(outcome.start.value == 1_620)
        #expect(outcome.end.value == 1_500)
        #expect(outcome.startedAt == Self.referenceDate)
        #expect(outcome.endedAt == Self.referenceDate.addingTimeInterval(60 * 86_400))
        #expect(outcome.delta == -120)
        #expect(outcome.isImprovement == true)
        #expect(outcome.durationDays == 60)
        #expect(outcome.basis.isFullyVerified == true)
    }

    @Test("happy path: higher-is-better metric (squat1RM) computed correctly, sorted by recordedAt")
    func happyPathHigherIsBetterMetric() throws {
        let engagement = makeEngagement()
        // Fed out of order to prove derive sorts by recordedAt rather than trusting input order.
        let progress = [
            progressEntry(engagementID: engagement.id, metric: .squat1RM, value: 315, unit: .lb, daysAfterReference: 45),
            progressEntry(engagementID: engagement.id, metric: .squat1RM, value: 225, unit: .lb, daysAfterReference: 0),
        ]

        let outcome = try #require(
            VerifiedOutcome.derive(
                from: engagement,
                metric: .squat1RM,
                progress: progress,
                completedSessions: [makeCompletedSession(engagementID: engagement.id)],
                payments: [makeSucceededPayment(engagementID: engagement.id)],
                clientConsent: true
            )
        )

        #expect(outcome.start.value == 225)
        #expect(outcome.end.value == 315)
        #expect(outcome.startedAt == Self.referenceDate)
        #expect(outcome.endedAt == Self.referenceDate.addingTimeInterval(45 * 86_400))
        #expect(outcome.delta == 90)
        #expect(outcome.isImprovement == true)
        #expect(outcome.durationDays == 45)
        #expect(outcome.basis.isFullyVerified == true)
    }

    @Test("progress entries for other metrics are excluded from the derived outcome")
    func filtersProgressToRequestedMetric() {
        let engagement = makeEngagement()
        let progress = [
            progressEntry(engagementID: engagement.id, metric: .bodyweight, value: 200, unit: .lb, daysAfterReference: 0),
            progressEntry(engagementID: engagement.id, metric: .squat1RM, value: 225, unit: .lb, daysAfterReference: 0),
        ]

        // Only one bodyweight point exists, so deriving a bodyweight outcome must fail
        // even though two total progress entries were supplied.
        let outcome = VerifiedOutcome.derive(
            from: engagement,
            metric: .bodyweight,
            progress: progress,
            completedSessions: [makeCompletedSession(engagementID: engagement.id)],
            payments: [makeSucceededPayment(engagementID: engagement.id)],
            clientConsent: true
        )

        #expect(outcome == nil)
    }
}
