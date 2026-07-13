import Foundation

/// The outcome status of a scheduled `Session`.
public enum SessionStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case scheduled
    case completed
    case cancelled
    case noShow
}
