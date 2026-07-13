import Foundation

/// Who or what recorded a `ProgressEntry`.
public enum ProgressSource: String, Codable, Sendable, Hashable, CaseIterable {
    case clientSelfReported
    case coachRecorded
    case inAppMeasured
}
