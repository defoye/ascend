import Foundation

/// A verified outcome: a measured change in a metric over the course of an
/// established, paid, consented coaching relationship.
///
/// This is Invariant 1 from docs/PRODUCT.md, enforced structurally: the memberwise
/// initializer below is `private`, so there is no code path anywhere in the app that
/// can construct a `VerifiedOutcome` without going through `derive`. `Codable`
/// synthesis still works alongside a private memberwise init — `Codable` generates
/// its own `init(from:)`/`encode(to:)`, which is independent of the memberwise init's
/// access level — so decoding from persisted/network data remains possible while
/// hand-authoring in application code does not compile.
public struct VerifiedOutcome: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<VerifiedOutcome>
    public let engagementID: Identifier<Engagement>
    public let metric: MetricKind
    public let start: MetricValue
    public let end: MetricValue
    public let startedAt: Date
    public let endedAt: Date
    public let basis: VerificationBasis

    private init(
        id: Identifier<VerifiedOutcome>,
        engagementID: Identifier<Engagement>,
        metric: MetricKind,
        start: MetricValue,
        end: MetricValue,
        startedAt: Date,
        endedAt: Date,
        basis: VerificationBasis
    ) {
        self.id = id
        self.engagementID = engagementID
        self.metric = metric
        self.start = start
        self.end = end
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.basis = basis
    }

    // swiftlint:disable function_parameter_count
    /// The sole public constructor. Returns `nil` unless every evidentiary pillar
    /// holds: an established relationship, at least one completed session, at least
    /// one succeeded payment, explicit client consent, and at least two
    /// time-separated progress measurements for `metric`.
    ///
    /// This signature is mandated verbatim by docs/DATA_MODEL.md — it is the sole
    /// public constructor of `VerifiedOutcome` and its shape is the point.
    public static func derive(
        from engagement: Engagement,
        metric: MetricKind,
        progress: [ProgressEntry],
        completedSessions: [Session],
        payments: [Payment],
        clientConsent: Bool
    ) -> VerifiedOutcome? {
        let basis = VerificationBasis(
            relationshipVerified: engagement.isEstablished,
            activityVerified: completedSessions.contains { $0.status == .completed },
            paymentVerified: payments.contains { $0.status == .succeeded },
            consentGranted: clientConsent
        )

        guard basis.isFullyVerified else { return nil }

        let points = progress
            .filter { $0.metric == metric }
            .sorted { $0.recordedAt < $1.recordedAt }

        let distinctTimestamps = Set(points.map(\.recordedAt))
        guard points.count >= 2, distinctTimestamps.count >= 2 else { return nil }

        guard let first = points.first, let last = points.last else { return nil }

        return VerifiedOutcome(
            id: Identifier(),
            engagementID: engagement.id,
            metric: metric,
            start: first.value,
            end: last.value,
            startedAt: first.recordedAt,
            endedAt: last.recordedAt,
            basis: basis
        )
    }
    // swiftlint:enable function_parameter_count

    /// The change in value from `start` to `end`, in `start`'s unit.
    public var delta: Double {
        end.value - start.value
    }

    /// Whether `delta` represents progress, given the metric's directionality.
    public var isImprovement: Bool {
        metric.lowerIsGenerallyBetter ? delta < 0 : delta > 0
    }

    /// Whole days between `startedAt` and `endedAt`.
    public var durationDays: Int {
        Int(endedAt.timeIntervalSince(startedAt) / 86_400)
    }
}
