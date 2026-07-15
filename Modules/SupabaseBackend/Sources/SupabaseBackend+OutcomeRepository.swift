import DataInterfaces
import Domain
import Foundation

/// `VerifiedOutcome.derive` (`Domain`) is the sole constructor of a
/// `VerifiedOutcome` (see docs/DATA_MODEL.md's "verified outcomes" invariant)
/// — this repository only gathers the evidence `derive` needs from Postgres
/// and calls it, exactly like `InMemoryBackend+OutcomeRepository.swift`
/// does against its in-memory dictionaries. There is no server-side
/// re-derivation logic to trust here or bypass: this client-side call *is*
/// the derivation, backed by real rows instead of a dictionary.
extension SupabaseBackend: OutcomeRepository {
    public func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] {
        let professionalEngagements = try await fetchEngagements(forProfessional: professionalID)
        var results: [VerifiedOutcome] = []
        for engagement in professionalEngagements {
            results.append(contentsOf: try await derivedOutcomes(for: engagement))
        }
        return results
    }

    public func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] {
        guard let engagement = try await get(engagementID) else { return [] }
        return try await derivedOutcomes(for: engagement)
    }

    // MARK: - Helpers

    private func derivedOutcomes(for engagement: Engagement) async throws -> [VerifiedOutcome] {
        let progress = try await fetchEntries(forEngagement: engagement.id)
        guard !progress.isEmpty else { return [] }

        let metrics = Set(progress.map(\.metric))
        let completedSessions = try await fetchSessions(forEngagement: engagement.id).filter { $0.status == .completed }
        let engagementPayments = try await payments(forEngagement: engagement.id)
        let consentGranted = try await consent(for: engagement.id)

        return metrics.compactMap { metric in
            VerifiedOutcome.derive(
                from: engagement,
                metric: metric,
                progress: progress,
                completedSessions: completedSessions,
                payments: engagementPayments,
                clientConsent: consentGranted
            )
        }
    }
}
