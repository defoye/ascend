import Foundation

/// A single measurement of a metric recorded at a point in time within an
/// `Engagement`.
public struct ProgressEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<ProgressEntry>
    public let engagementID: Identifier<Engagement>
    public let metric: MetricKind
    public let value: MetricValue
    public let recordedAt: Date
    public let source: ProgressSource

    public init(
        id: Identifier<ProgressEntry>,
        engagementID: Identifier<Engagement>,
        metric: MetricKind,
        value: MetricValue,
        recordedAt: Date,
        source: ProgressSource
    ) {
        self.id = id
        self.engagementID = engagementID
        self.metric = metric
        self.value = value
        self.recordedAt = recordedAt
        self.source = source
    }
}
