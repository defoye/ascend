import Domain
import Foundation

/// Aggregate stats shown at the top of the coach's Proof Profile: how much
/// verifiable activity backs the practice, independent of any single
/// `VerifiedOutcome`.
public struct ProofProfileStats: Sendable, Equatable {
    /// Every `.completed` session across all of the professional's engagements.
    public let sessionsCompleted: Int
    /// Engagements currently `.active`.
    public let activeClients: Int
    /// Share of established relationships (`Engagement.isEstablished`) that
    /// have not `.ended` — `nil` when there are no established relationships
    /// yet to measure, so the UI can show "—" instead of a misleading 0%.
    public let retentionRate: Double?

    public init(sessionsCompleted: Int, activeClients: Int, retentionRate: Double?) {
        self.sessionsCompleted = sessionsCompleted
        self.activeClients = activeClients
        self.retentionRate = retentionRate
    }

    public static let zero = ProofProfileStats(sessionsCompleted: 0, activeClients: 0, retentionRate: nil)
}

/// A single `VerifiedOutcome`, paired with its display copy, ready for the
/// Proof Profile's journeys list.
///
/// Deliberately carries no client identity — `description` is built purely
/// from the outcome's metric/values/duration (see
/// `ProofProfileSummaries.journeyDescription`), keeping journeys anonymized
/// per docs/design/DESIGN_SPEC.md §1 ("*anonymized* journeys with explicit
/// non-causation copy").
public struct VerifiedJourney: Sendable, Identifiable, Equatable {
    public let id: Identifier<VerifiedOutcome>
    public let outcome: VerifiedOutcome
    public let description: String

    public init(outcome: VerifiedOutcome, description: String) {
        self.id = outcome.id
        self.outcome = outcome
        self.description = description
    }
}

/// Pure, directly-testable math behind the coach "Proof Profile" screen. Kept
/// free of any backend/view-model dependency so tests can exercise the
/// arithmetic and copy straight against seeded fixtures (see
/// docs/TESTING.md), mirroring `TodaySummaries`.
///
/// Every `VerifiedOutcome` this type touches has already gone through
/// `Domain.VerifiedOutcome.derive` (via `OutcomeRepository`) by the time it
/// gets here — this type never constructs one, only formats what `derive`
/// yielded (Invariant 1, docs/PRODUCT.md).
public enum ProofProfileSummaries {
    /// Aggregate stats across every engagement of a single professional.
    public static func stats(engagements: [Engagement], sessions: [Session]) -> ProofProfileStats {
        let sessionsCompleted = sessions.filter { $0.status == .completed }.count
        let activeClients = engagements.filter { $0.status == .active }.count

        let established = engagements.filter(\.isEstablished)
        let retentionRate: Double? = established.isEmpty
            ? nil
            : Double(established.filter { $0.status != .ended }.count) / Double(established.count)

        return ProofProfileStats(sessionsCompleted: sessionsCompleted, activeClients: activeClients, retentionRate: retentionRate)
    }

    /// Maps derived outcomes to display-ready journeys, most recently
    /// completed first (a stable, deterministic order for the list).
    public static func journeys(from outcomes: [VerifiedOutcome]) -> [VerifiedJourney] {
        outcomes
            .sorted { $0.endedAt > $1.endedAt }
            .map { VerifiedJourney(outcome: $0, description: journeyDescription(for: $0)) }
    }

    /// Renders a `VerifiedOutcome` as journey copy, e.g. "Client · squat 1RM
    /// 185 → 225 lb · 4 weeks".
    ///
    /// Invariant 2 (docs/PRODUCT.md): this string names no client, and
    /// describes a measured change over a real relationship — it never
    /// claims the coach caused the result. "Client" is a generic role label,
    /// not an identity.
    public static func journeyDescription(for outcome: VerifiedOutcome) -> String {
        journeyDescription(metric: outcome.metric, start: outcome.start, end: outcome.end, durationDays: outcome.durationDays)
    }

    /// The same journey copy as `journeyDescription(for:)`, built from
    /// primitives instead of a `VerifiedOutcome`. Exists so a "Tracked
    /// results" journey (`TrackedJourneySummaries`, surfaced while
    /// `PaymentsMode` is `.free`) can render **identical** phrasing without
    /// ever constructing a `VerifiedOutcome` — Tracked journeys deliberately
    /// don't have one (Option B, docs/BACKEND.md "PaymentsMode: free-first rollout").
    public static func journeyDescription(metric: MetricKind, start: MetricValue, end: MetricValue, durationDays: Int) -> String {
        let weeks = max(1, durationDays / 7)
        let weekWord = weeks == 1 ? "week" : "weeks"
        let startText = formattedNumber(start.value)
        let endText = formattedNumber(end.value)
        let unit = end.unit.shortLabel
        return "Client · \(metric.displayName) \(startText) → \(endText) \(unit) · \(weeks) \(weekWord)"
    }

    /// A one-line, delta-first summary for a journey row/detail sheet, e.g.
    /// "Client · squat 1RM · 4 weeks · +40 lb, measured" — matching the
    /// anonymized-journey copy shape in docs/design/CLAUDE_DESIGN_BRIEF.md
    /// ("Client, {age} · {category} · {weeks} weeks · {delta}, measured")
    /// as closely as the data model allows: `Domain.Person` carries no age,
    /// so age is omitted rather than invented (Invariant 1, docs/PRODUCT.md),
    /// and `{category}` is `metric.displayName` — the closest honest
    /// category label a `VerifiedOutcome`/`TrackedJourney` actually carries.
    /// Kept separate from `journeyDescription`, which existing tests and
    /// call sites already depend on verbatim.
    public static func journeySummaryLine(metric: MetricKind, start: MetricValue, end: MetricValue, durationDays: Int) -> String {
        let weeks = max(1, durationDays / 7)
        let weekWord = weeks == 1 ? "week" : "weeks"
        let delta = end.value - start.value
        let sign = delta < 0 ? "\u{2212}" : (delta > 0 ? "+" : "")
        let magnitude = formattedNumber(abs(delta))
        let unit = end.unit.shortLabel
        return "Client · \(metric.displayName) · \(weeks) \(weekWord) · \(sign)\(magnitude) \(unit), measured"
    }

    private static func formattedNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
