import Foundation

/// The lifecycle status of an `Engagement`.
public enum EngagementStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case active
    case paused
    case completed
    case ended
}
