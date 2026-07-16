import DataInterfaces
import Domain
import Foundation

/// Pure mode → copy mapping for the Proof Profile's Verified/Tracked split.
/// Kept as a standalone, directly-testable type so a test can assert the
/// `.free` line never contains the word "Verified" (Invariant 2, see
/// docs/PRODUCT.md and docs/design/CLAUDE_DESIGN_BRIEF.md "Constraints" —
/// "Verified journey," not "Verified results"; free/unpaid mode is
/// "Tracked," never "Verified").
public enum ProofProfileCopy {
    /// The substantiation line shown under a journey/Tracked-result section
    /// header and in the journey-detail sheet's "Backed by" line. Verbatim
    /// per docs/design/CLAUDE_DESIGN_BRIEF.md "Content & data".
    public static func substantiationLine(for mode: PaymentsMode) -> String {
        switch mode {
        case .live: "Backed by a real, paid coaching relationship & tracked measurements."
        case .free: "Self-tracked progress over an active coaching relationship."
        }
    }
}

/// Anonymized, derive-only content for the journey-detail bottom sheet — a
/// metric trajectory (start/end, honestly two points when that's all the
/// underlying evidence carries), timeframe, measured delta, and the
/// mode-appropriate "Backed by" line. Built exclusively from a
/// `VerifiedJourney`/`TrackedJourney` that a prior derivation step already
/// produced — this type never touches raw progress data itself and never
/// authors an outcome (Invariant 1, docs/PRODUCT.md). Carries no client name
/// or photo (Invariant 2).
public struct JourneyDetailContent: Identifiable, Equatable, Sendable {
    public let id: String
    public let metricDisplayName: String
    public let unit: MetricUnit
    public let start: MetricValue
    public let end: MetricValue
    public let startedAt: Date
    public let endedAt: Date
    public let weeks: Int
    public let summaryLine: String
    public let substantiationLine: String
    /// Mirrors `Domain.MetricKind.lowerIsGenerallyBetter` for the sheet's
    /// trajectory chart, so a weight-loss journey's delta still reads as an
    /// improvement (success-colored) even though the value went down.
    public let lowerIsBetter: Bool
    /// Drives the sheet's badge lock-up (`VerifiedBadge` vs `TrackedBadge`)
    /// and whether the teal verified treatment applies — never `true` while
    /// `PaymentsMode` is `.free` (see `ProofProfileCopy`/Invariant 2).
    public let isVerified: Bool

    public static func verified(_ journey: VerifiedJourney, mode: PaymentsMode) -> JourneyDetailContent {
        let outcome = journey.outcome
        return JourneyDetailContent(
            id: outcome.id.rawValue,
            metricDisplayName: outcome.metric.displayName,
            unit: outcome.end.unit,
            start: outcome.start,
            end: outcome.end,
            startedAt: outcome.startedAt,
            endedAt: outcome.endedAt,
            weeks: max(1, outcome.durationDays / 7),
            summaryLine: ProofProfileSummaries.journeySummaryLine(
                metric: outcome.metric, start: outcome.start, end: outcome.end, durationDays: outcome.durationDays
            ),
            substantiationLine: ProofProfileCopy.substantiationLine(for: mode),
            lowerIsBetter: outcome.metric.lowerIsGenerallyBetter,
            isVerified: mode == .live
        )
    }

    public static func tracked(_ journey: TrackedJourney, mode: PaymentsMode) -> JourneyDetailContent {
        let durationDays = Int(journey.lastRecordedAt.timeIntervalSince(journey.startedAt) / 86_400)
        return JourneyDetailContent(
            id: journey.id,
            metricDisplayName: journey.metric.displayName,
            unit: journey.end.unit,
            start: journey.start,
            end: journey.end,
            startedAt: journey.startedAt,
            endedAt: journey.lastRecordedAt,
            weeks: max(1, durationDays / 7),
            summaryLine: ProofProfileSummaries.journeySummaryLine(
                metric: journey.metric, start: journey.start, end: journey.end, durationDays: durationDays
            ),
            substantiationLine: ProofProfileCopy.substantiationLine(for: mode),
            lowerIsBetter: journey.metric.lowerIsGenerallyBetter,
            // Tracked journeys never claim Verified, regardless of the mode
            // argument's provenance — this is never `true` in practice since
            // `.tracked` is only ever called while `.free`.
            isVerified: false
        )
    }
}
