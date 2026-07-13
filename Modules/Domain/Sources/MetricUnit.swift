import Foundation

/// The unit a `MetricValue` is expressed in.
public enum MetricUnit: String, Codable, Sendable, Hashable, CaseIterable {
    case lb
    case kg
    case inch
    case cm
    case percent
    case bpm
    case seconds
}
