import Foundation

/// The vertical a `Service` belongs to. New verticals are added as new cases here,
/// never as new architecture (see docs/PRODUCT.md — "trainer" is never a type in the
/// data model).
public enum ServiceCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case strengthTraining
    case weightLoss
    case mobility
    case running
    case sportsPerformance
    case yoga
    case pilates
    case physicalTherapy
    case generalFitness
}
