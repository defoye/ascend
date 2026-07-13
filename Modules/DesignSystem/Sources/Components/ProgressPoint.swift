import Foundation

/// A single measured point in time, e.g. a weight or performance metric
/// reading. Plain data — never a `Domain` type — so `DesignSystem` stays
/// dependency-free (see docs/ARCHITECTURE.md).
public struct ProgressPoint: Identifiable, Sendable, Equatable {
    public let date: Date
    public let value: Double

    public var id: Date { date }

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}
