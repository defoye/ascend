import Domain
import Foundation

/// A "Tracked result": a journey that satisfies every non-payment pillar of
/// `Domain.VerifiedOutcome.derive` (established relationship, at least one
/// completed session, client consent, and 2+ time-separated measurements of
/// a metric — see docs/DATA_MODEL.md) but does **not** claim the payment
/// pillar.
///
/// A `TrackedJourney` is a separate, clearly-labeled Features-level type —
/// it is never a `Domain.VerifiedOutcome` and this file never constructs
/// one. Surfaced only while `PaymentsMode` is `.free`; once payments turn on
/// the same underlying engagement/metric would instead surface as a
/// `VerifiedJourney` via `ProofProfileSummaries.journeys(from:)` (Option B,
/// see docs/BUILD_STATUS.md "Rollout strategy — free first, monetize
/// later").
public struct TrackedJourney: Sendable, Identifiable, Equatable {
    public let id: String
    public let engagementID: Identifier<Engagement>
    public let metric: MetricKind
    public let description: String
    /// The most recent progress measurement's timestamp — used to sort
    /// Tracked results most-recent-first, mirroring
    /// `ProofProfileSummaries.journeys(from:)`'s `endedAt` ordering.
    public let lastRecordedAt: Date

    public init(engagementID: Identifier<Engagement>, metric: MetricKind, description: String, lastRecordedAt: Date) {
        self.id = "\(engagementID.rawValue)-\(metric.rawValue)"
        self.engagementID = engagementID
        self.metric = metric
        self.description = description
        self.lastRecordedAt = lastRecordedAt
    }
}

/// One engagement's raw evidence for Tracked-journey derivation — everything
/// `TrackedJourneySummaries.trackedJourneys(from:)` needs for a single
/// engagement, gathered by `ProofProfileViewModel` from the same
/// repositories `OutcomeRepository`'s adapters use, just without a
/// `Payment` (see `TrackedJourneySummaries`).
public struct TrackedEngagementEvidence: Sendable {
    public let engagement: Engagement
    public let progress: [ProgressEntry]
    public let completedSessions: [Session]
    public let clientConsent: Bool

    public init(engagement: Engagement, progress: [ProgressEntry], completedSessions: [Session], clientConsent: Bool) {
        self.engagement = engagement
        self.progress = progress
        self.completedSessions = completedSessions
        self.clientConsent = clientConsent
    }
}

/// Pure, directly-testable math behind "Tracked results" — the `.free`-mode
/// counterpart to `ProofProfileSummaries`'s `VerifiedJourney` derivation.
/// Deliberately mirrors the non-payment pillars of `Domain.VerifiedOutcome.derive`
/// verbatim (down to the "2+ time-separated measurements" rule) so that
/// turning payments on later reveals *exactly* the same set of journeys as
/// Verified, never more or fewer. Never calls `VerifiedOutcome.derive` or
/// constructs a `VerifiedOutcome` — this type has no notion of payment at
/// all.
public enum TrackedJourneySummaries {
    /// Derives every Tracked journey (one per metric with qualifying
    /// progress) across a set of engagements, most-recent-first.
    public static func trackedJourneys(from evidence: [TrackedEngagementEvidence]) -> [TrackedJourney] {
        evidence
            .flatMap(trackedJourneys(for:))
            .sorted { $0.lastRecordedAt > $1.lastRecordedAt }
    }

    /// Derives every Tracked journey for a single engagement. Mirrors
    /// `VerifiedOutcome.derive`'s guard order: relationship established,
    /// >=1 completed session, and consent granted gate the engagement
    /// entirely; then each metric with >=2 time-separated progress points
    /// yields its own journey.
    static func trackedJourneys(for evidence: TrackedEngagementEvidence) -> [TrackedJourney] {
        guard evidence.engagement.isEstablished,
              evidence.completedSessions.contains(where: { $0.status == .completed }),
              evidence.clientConsent
        else { return [] }

        let metrics = Set(evidence.progress.map(\.metric))
        return metrics.compactMap { metric in
            let points = evidence.progress
                .filter { $0.metric == metric }
                .sorted { $0.recordedAt < $1.recordedAt }
            let distinctTimestamps = Set(points.map(\.recordedAt))
            guard points.count >= 2, distinctTimestamps.count >= 2,
                  let first = points.first, let last = points.last
            else { return nil }

            let durationDays = Int(last.recordedAt.timeIntervalSince(first.recordedAt) / 86_400)
            let description = ProofProfileSummaries.journeyDescription(
                metric: metric,
                start: first.value,
                end: last.value,
                durationDays: durationDays
            )
            return TrackedJourney(
                engagementID: evidence.engagement.id,
                metric: metric,
                description: description,
                lastRecordedAt: last.recordedAt
            )
        }
    }
}
