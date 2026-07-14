import DataInterfaces
import Domain
import Foundation

// MARK: - Verified outcomes fixture
//
// Split into its own file (rather than kept in `PreviewBackend.swift`) purely
// to stay under SwiftLint's `file_length` — SwiftLint measures each file
// independently.

/// Derives real `VerifiedOutcome`s from the preview fixture's own
/// engagements/sessions/progress/payments, exactly the way `InMemoryBackend`
/// does (`derive` is the only construction path — see docs/DATA_MODEL.md) —
/// so `#Preview`s of outcome-driven screens (e.g. `ProofProfileView`) show
/// real content instead of an empty state.
struct PreviewOutcomeRepository: OutcomeRepository {
    let engagements: [Engagement]
    let sessionsByEngagement: [Identifier<Engagement>: [Session]]
    let progressByEngagement: [Identifier<Engagement>: [ProgressEntry]]
    let paymentsByEngagement: [Identifier<Engagement>: [Payment]]

    func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] {
        engagements
            .filter { $0.professionalID == professionalID }
            .flatMap(derivedOutcomes)
    }

    func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] {
        guard let engagement = engagements.first(where: { $0.id == engagementID }) else { return [] }
        return derivedOutcomes(for: engagement)
    }

    private func derivedOutcomes(for engagement: Engagement) -> [VerifiedOutcome] {
        let progress = progressByEngagement[engagement.id] ?? []
        guard !progress.isEmpty else { return [] }

        let completedSessions = (sessionsByEngagement[engagement.id] ?? []).filter { $0.status == .completed }
        let payments = paymentsByEngagement[engagement.id] ?? []
        let metrics = Set(progress.map(\.metric))

        return metrics.compactMap { metric in
            VerifiedOutcome.derive(
                from: engagement,
                metric: metric,
                progress: progress,
                completedSessions: completedSessions,
                payments: payments,
                clientConsent: true
            )
        }
    }
}
