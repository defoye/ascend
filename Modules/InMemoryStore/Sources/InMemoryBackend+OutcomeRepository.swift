import DataInterfaces
import Domain

extension InMemoryBackend: OutcomeRepository {
    public func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] {
        let professionalEngagements = engagementsByID.values.filter { $0.professionalID == professionalID }
        var results: [VerifiedOutcome] = []
        for engagement in professionalEngagements {
            results.append(contentsOf: derivedOutcomes(for: engagement))
        }
        return results
    }

    public func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] {
        guard let engagement = engagementsByID[engagementID] else { return [] }
        return derivedOutcomes(for: engagement)
    }

    /// Derives one `VerifiedOutcome` per metric that has recorded progress for
    /// `engagement`. `VerifiedOutcome.derive` is the sole constructor (see
    /// docs/DATA_MODEL.md); this method only gathers the evidence it needs.
    private func derivedOutcomes(for engagement: Engagement) -> [VerifiedOutcome] {
        let progress = progressList(forEngagement: engagement.id)
        guard !progress.isEmpty else { return [] }

        let metrics = Set(progress.map(\.metric))
        let completedSessions = sessionsList(forEngagement: engagement.id).filter { $0.status == .completed }
        let engagementPayments = paymentsByID.values.filter { $0.engagementID == engagement.id }
        let consentGranted = consentByEngagement[engagement.id] ?? false

        return metrics.compactMap { metric in
            VerifiedOutcome.derive(
                from: engagement,
                metric: metric,
                progress: progress,
                completedSessions: completedSessions,
                payments: Array(engagementPayments),
                clientConsent: consentGranted
            )
        }
    }
}
