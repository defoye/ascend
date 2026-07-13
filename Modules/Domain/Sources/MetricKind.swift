import Foundation

/// The kind of metric being tracked, e.g. as a `Goal` target or `ProgressEntry`.
public enum MetricKind: String, Codable, Sendable, Hashable, CaseIterable {
    case bodyweight
    case waistCircumference
    case squat1RM
    case bench1RM
    case deadlift1RM
    case bodyFatPercentage
    case restingHeartRate
    case fiveKTime

    /// Whether a lower value of this metric represents progress. Strength 1RMs get
    /// better as they go up; body composition, resting heart rate, and race times
    /// get better as they go down.
    public var lowerIsGenerallyBetter: Bool {
        switch self {
        case .squat1RM, .bench1RM, .deadlift1RM:
            false
        case .bodyweight, .waistCircumference, .bodyFatPercentage, .restingHeartRate, .fiveKTime:
            true
        }
    }
}
