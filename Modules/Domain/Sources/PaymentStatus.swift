import Foundation

/// The lifecycle status of a `Payment`.
public enum PaymentStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case pending
    case succeeded
    case refunded
    case failed
}
