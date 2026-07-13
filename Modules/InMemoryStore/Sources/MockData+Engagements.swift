import Domain
import Foundation

extension MockData {
    /// Per-client fixture status, matching `clientNames` by index (see
    /// `MockData+People.swift`). Chosen so the eight clients span every
    /// `EngagementStatus`, and so five engagements (1, 2, 4, 5, 7) independently
    /// satisfy every pillar of `VerifiedOutcome.derive` — comfortably above the
    /// "at least 3" requirement — while three (0, 3, 6) each fail exactly one
    /// pillar, exercising `derive`'s eligibility gates with realistic data:
    ///   0. Alex Rivera     — pending, not yet established.
    ///   1. Morgan Chen     — active; bodyweight progress. Derives.
    ///   2. Sam Patel       — active; squat1RM progress. Derives.
    ///   3. Taylor Brooks   — active; only one progress point (not time-separated
    ///                        pair). Fails the progress-points pillar.
    ///   4. Jamie Nguyen    — paused; fiveKTime progress. Derives.
    ///   5. Casey Whitfield — completed; waistCircumference progress. Derives.
    ///   6. Riley Thompson  — completed; bench1RM progress, but consent withheld.
    ///                        Fails the consent pillar.
    ///   7. Drew Bennett    — ended; deadlift1RM progress before the relationship
    ///                        ended. Derives.
    static func engagementID(_ index: Int) -> Identifier<Engagement> {
        Identifier(uuid(6, UInt8(index)))
    }

    static func engagements() -> [Engagement] {
        [
            makeEngagement(0, status: .pending, startedAt: nil, endedAt: nil),
            makeEngagement(1, status: .active, startedAt: date(-100), endedAt: nil),
            makeEngagement(2, status: .active, startedAt: date(-70), endedAt: nil),
            makeEngagement(3, status: .active, startedAt: date(-20), endedAt: nil),
            makeEngagement(4, status: .paused, startedAt: date(-150), endedAt: nil),
            makeEngagement(5, status: .completed, startedAt: date(-200), endedAt: date(-20)),
            makeEngagement(6, status: .completed, startedAt: date(-180), endedAt: date(-40)),
            makeEngagement(7, status: .ended, startedAt: date(-250), endedAt: date(-200))
        ]
    }

    private static func makeEngagement(
        _ index: Int,
        status: EngagementStatus,
        startedAt: Date?,
        endedAt: Date?
    ) -> Engagement {
        Engagement(
            id: engagementID(index),
            clientID: clientPersonID(index),
            professionalID: professionalPersonID,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    static func consentByEngagement() -> [Identifier<Engagement>: Bool] {
        [
            engagementID(1): true,
            engagementID(2): true,
            engagementID(3): true,
            engagementID(4): true,
            engagementID(5): true,
            engagementID(6): false, // consent withheld: derive must fail despite rich data.
            engagementID(7): true
        ]
    }
}
