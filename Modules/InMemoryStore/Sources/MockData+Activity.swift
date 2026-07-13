import Domain
import Foundation

extension MockData {
    struct ActivityData {
        let engagements: [Engagement]
        let consentByEngagement: [Identifier<Engagement>: Bool]
        let sessions: [Session]
        let progressEntries: [ProgressEntry]
        let payments: [Payment]
        let messages: [Message]
    }

    struct ClientActivity {
        var sessions: [Session] = []
        var progress: [ProgressEntry] = []
        var payments: [Payment] = []
        var messages: [Message] = []
    }

    static func activityData() -> ActivityData {
        let clients = [
            client1Activity(), client2Activity(), client3Activity(), client4Activity(),
            client5Activity(), client6Activity(), client7Activity()
        ]
        return ActivityData(
            engagements: engagements(),
            consentByEngagement: consentByEngagement(),
            sessions: clients.flatMap(\.sessions),
            progressEntries: clients.flatMap(\.progress),
            payments: clients.flatMap(\.payments),
            messages: clients.flatMap(\.messages)
        )
    }

    // MARK: - Fixture factories

    static func mockSession(_ index: UInt8, engagement: Int, daysOffset: Int, status: SessionStatus) -> Session {
        Session(id: Identifier(uuid(13, index)), engagementID: engagementID(engagement), scheduledAt: date(daysOffset), status: status)
    }

    static func mockPayment(_ index: UInt8, engagement: Int, daysOffset: Int, amountCents: Int) -> Payment {
        Payment(
            id: Identifier(uuid(15, index)),
            engagementID: engagementID(engagement),
            amountCents: amountCents,
            currency: "USD",
            status: .succeeded,
            platformFeeCents: amountCents / 10,
            stripePaymentIntentID: "pi_mock_\(index)",
            createdAt: date(daysOffset)
        )
    }

    // swiftlint:disable:next function_parameter_count
    static func mockProgress(
        _ index: UInt8,
        engagement: Int,
        metric: MetricKind,
        value: Double,
        unit: MetricUnit,
        daysOffset: Int,
        source: ProgressSource
    ) -> ProgressEntry {
        ProgressEntry(
            id: Identifier(uuid(14, index)),
            engagementID: engagementID(engagement),
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: date(daysOffset),
            source: source
        )
    }

    // swiftlint:disable:next function_parameter_count
    static func mockMessage(
        _ index: UInt8,
        engagement: Int,
        from clientIndex: Int,
        isFromCoach: Bool,
        body: String,
        daysOffset: Int
    ) -> Message {
        let author = isFromCoach ? professionalPersonID : clientPersonID(clientIndex)
        return Message(id: Identifier(uuid(16, index)), engagementID: engagementID(engagement), authorID: author, body: body, sentAt: date(daysOffset))
    }

    // MARK: - Client 1: Morgan Chen — active, bodyweight progress, derives.

    static func client1Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(0, engagement: 1, daysOffset: -95, status: .completed),
            mockSession(1, engagement: 1, daysOffset: -80, status: .completed),
            mockSession(2, engagement: 1, daysOffset: -65, status: .completed),
            mockSession(3, engagement: 1, daysOffset: -50, status: .completed),
            mockSession(4, engagement: 1, daysOffset: -35, status: .completed),
            mockSession(5, engagement: 1, daysOffset: 7, status: .scheduled)
        ]
        activity.payments = [
            mockPayment(0, engagement: 1, daysOffset: -98, amountCents: 12_000),
            mockPayment(1, engagement: 1, daysOffset: -30, amountCents: 12_000)
        ]
        activity.progress = [
            mockProgress(0, engagement: 1, metric: .bodyweight, value: 210, unit: .lb, daysOffset: -100, source: .clientSelfReported),
            mockProgress(1, engagement: 1, metric: .bodyweight, value: 205, unit: .lb, daysOffset: -60, source: .coachRecorded),
            mockProgress(2, engagement: 1, metric: .bodyweight, value: 200, unit: .lb, daysOffset: -30, source: .coachRecorded),
            mockProgress(3, engagement: 1, metric: .bodyweight, value: 196, unit: .lb, daysOffset: 0, source: .clientSelfReported)
        ]
        activity.messages = [
            mockMessage(0, engagement: 1, from: 1, isFromCoach: false, body: "Excited to get started!", daysOffset: -99),
            mockMessage(1, engagement: 1, from: 1, isFromCoach: true, body: "Let's aim for 3 sessions a week to start.", daysOffset: -99),
            mockMessage(2, engagement: 1, from: 1, isFromCoach: false, body: "Down 14 lbs so far, feeling great.", daysOffset: -30)
        ]
        return activity
    }

    // MARK: - Client 2: Sam Patel — active, squat1RM progress, derives.

    static func client2Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(6, engagement: 2, daysOffset: -65, status: .completed),
            mockSession(7, engagement: 2, daysOffset: -50, status: .completed),
            mockSession(8, engagement: 2, daysOffset: -35, status: .completed),
            mockSession(9, engagement: 2, daysOffset: -20, status: .completed),
            mockSession(10, engagement: 2, daysOffset: 5, status: .scheduled)
        ]
        activity.payments = [
            mockPayment(2, engagement: 2, daysOffset: -65, amountCents: 15_000)
        ]
        activity.progress = [
            mockProgress(4, engagement: 2, metric: .squat1RM, value: 185, unit: .lb, daysOffset: -70, source: .coachRecorded),
            mockProgress(5, engagement: 2, metric: .squat1RM, value: 205, unit: .lb, daysOffset: -40, source: .coachRecorded),
            mockProgress(6, engagement: 2, metric: .squat1RM, value: 225, unit: .lb, daysOffset: -10, source: .coachRecorded)
        ]
        activity.messages = [
            mockMessage(3, engagement: 2, from: 2, isFromCoach: true, body: "New squat max today: 225!", daysOffset: -10),
            mockMessage(4, engagement: 2, from: 2, isFromCoach: false, body: "Didn't think I'd hit that so soon.", daysOffset: -10)
        ]
        return activity
    }

    // MARK: - Client 3: Taylor Brooks — active, one progress point, fails derive.

    static func client3Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(11, engagement: 3, daysOffset: -18, status: .completed)
        ]
        activity.payments = [
            mockPayment(3, engagement: 3, daysOffset: -19, amountCents: 12_000)
        ]
        activity.progress = [
            mockProgress(7, engagement: 3, metric: .bodyweight, value: 178, unit: .lb, daysOffset: -20, source: .clientSelfReported)
        ]
        activity.messages = [
            mockMessage(5, engagement: 3, from: 3, isFromCoach: false, body: "Just signed up, ready to go.", daysOffset: -20)
        ]
        return activity
    }

    // MARK: - Client 4: Jamie Nguyen — paused, fiveKTime progress, derives.

    static func client4Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(12, engagement: 4, daysOffset: -145, status: .completed),
            mockSession(13, engagement: 4, daysOffset: -130, status: .completed),
            mockSession(14, engagement: 4, daysOffset: -110, status: .completed)
        ]
        activity.payments = [
            mockPayment(4, engagement: 4, daysOffset: -145, amountCents: 15_000)
        ]
        activity.progress = [
            mockProgress(8, engagement: 4, metric: .fiveKTime, value: 1_800, unit: .seconds, daysOffset: -150, source: .inAppMeasured),
            mockProgress(9, engagement: 4, metric: .fiveKTime, value: 1_740, unit: .seconds, daysOffset: -120, source: .inAppMeasured),
            mockProgress(10, engagement: 4, metric: .fiveKTime, value: 1_700, unit: .seconds, daysOffset: -100, source: .inAppMeasured)
        ]
        activity.messages = [
            mockMessage(6, engagement: 4, from: 4, isFromCoach: false, body: "Need to pause for a few weeks, work travel.", daysOffset: -95),
            mockMessage(7, engagement: 4, from: 4, isFromCoach: true, body: "No worries, we'll pick back up when you're back.", daysOffset: -95)
        ]
        return activity
    }

    // MARK: - Client 5: Casey Whitfield — completed, waistCircumference progress, derives.

    static func client5Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(15, engagement: 5, daysOffset: -195, status: .completed),
            mockSession(16, engagement: 5, daysOffset: -160, status: .completed),
            mockSession(17, engagement: 5, daysOffset: -120, status: .completed),
            mockSession(18, engagement: 5, daysOffset: -80, status: .completed),
            mockSession(19, engagement: 5, daysOffset: -60, status: .noShow),
            mockSession(20, engagement: 5, daysOffset: -40, status: .completed)
        ]
        activity.payments = [
            mockPayment(5, engagement: 5, daysOffset: -195, amountCents: 12_000),
            mockPayment(6, engagement: 5, daysOffset: -100, amountCents: 12_000)
        ]
        activity.progress = [
            mockProgress(11, engagement: 5, metric: .waistCircumference, value: 38, unit: .inch, daysOffset: -200, source: .coachRecorded),
            mockProgress(12, engagement: 5, metric: .waistCircumference, value: 36, unit: .inch, daysOffset: -150, source: .coachRecorded),
            mockProgress(13, engagement: 5, metric: .waistCircumference, value: 34.5, unit: .inch, daysOffset: -100, source: .coachRecorded),
            mockProgress(14, engagement: 5, metric: .waistCircumference, value: 33, unit: .inch, daysOffset: -30, source: .coachRecorded)
        ]
        activity.messages = [
            mockMessage(8, engagement: 5, from: 5, isFromCoach: false, body: "Wrapping up here, thank you for everything!", daysOffset: -22),
            mockMessage(9, engagement: 5, from: 5, isFromCoach: true, body: "Huge congrats on the progress, Casey.", daysOffset: -21)
        ]
        return activity
    }

    // MARK: - Client 6: Riley Thompson — completed, bench1RM progress, consent withheld.

    static func client6Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(21, engagement: 6, daysOffset: -175, status: .completed),
            mockSession(22, engagement: 6, daysOffset: -140, status: .completed),
            mockSession(23, engagement: 6, daysOffset: -100, status: .completed),
            mockSession(24, engagement: 6, daysOffset: -60, status: .completed)
        ]
        activity.payments = [
            mockPayment(7, engagement: 6, daysOffset: -175, amountCents: 15_000),
            mockPayment(8, engagement: 6, daysOffset: -90, amountCents: 15_000)
        ]
        activity.progress = [
            mockProgress(15, engagement: 6, metric: .bench1RM, value: 135, unit: .lb, daysOffset: -180, source: .coachRecorded),
            mockProgress(16, engagement: 6, metric: .bench1RM, value: 145, unit: .lb, daysOffset: -130, source: .coachRecorded),
            mockProgress(17, engagement: 6, metric: .bench1RM, value: 155, unit: .lb, daysOffset: -80, source: .coachRecorded)
        ]
        activity.messages = [
            mockMessage(10, engagement: 6, from: 6, isFromCoach: false, body: "That's a wrap for me, thanks Jordan.", daysOffset: -41)
        ]
        return activity
    }

    // MARK: - Client 7: Drew Bennett — ended, deadlift1RM progress, derives.

    static func client7Activity() -> ClientActivity {
        var activity = ClientActivity()
        activity.sessions = [
            mockSession(25, engagement: 7, daysOffset: -245, status: .completed),
            mockSession(26, engagement: 7, daysOffset: -230, status: .completed),
            mockSession(27, engagement: 7, daysOffset: -215, status: .completed),
            mockSession(28, engagement: 7, daysOffset: -205, status: .cancelled)
        ]
        activity.payments = [
            mockPayment(9, engagement: 7, daysOffset: -245, amountCents: 15_000)
        ]
        activity.progress = [
            mockProgress(18, engagement: 7, metric: .deadlift1RM, value: 315, unit: .lb, daysOffset: -250, source: .coachRecorded),
            mockProgress(19, engagement: 7, metric: .deadlift1RM, value: 335, unit: .lb, daysOffset: -220, source: .coachRecorded)
        ]
        activity.messages = [
            mockMessage(11, engagement: 7, from: 7, isFromCoach: false, body: "I need to step away from training for now.", daysOffset: -206)
        ]
        return activity
    }
}
