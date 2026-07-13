import Foundation

/// A numeric measurement paired with its unit.
public struct MetricValue: Codable, Sendable, Hashable {
    public let value: Double
    public let unit: MetricUnit

    public init(value: Double, unit: MetricUnit) {
        self.value = value
        self.unit = unit
    }
}
