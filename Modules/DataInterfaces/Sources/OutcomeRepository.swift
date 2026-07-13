import Domain

/// Derives and returns `VerifiedOutcome`s.
///
/// The only path to a `VerifiedOutcome` is `VerifiedOutcome.derive` (see
/// docs/DATA_MODEL.md) — implementations of this protocol gather the evidence
/// (`Engagement`, `Session`s, `Payment`s, consent, and `ProgressEntry` points)
/// and call `derive`; they never construct one another way.
public protocol OutcomeRepository: Sendable {
    func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome]
    func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome]
}
