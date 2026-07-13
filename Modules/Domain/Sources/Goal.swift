import Foundation

/// A goal a `Person` is pursuing, optionally tied to a measurable metric and target.
public struct Goal: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Goal>
    public let kind: GoalKind
    public let metric: MetricKind?
    public let target: MetricValue?
    public let deadline: Date?

    public init(
        id: Identifier<Goal>,
        kind: GoalKind,
        metric: MetricKind?,
        target: MetricValue?,
        deadline: Date?
    ) {
        self.id = id
        self.kind = kind
        self.metric = metric
        self.target = target
        self.deadline = deadline
    }
}
