import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's "Proof Profile" screen: verification badges,
/// aggregate practice stats, and anonymized verified journeys.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md) — never a
/// concrete backend adapter. Journeys come exclusively from
/// `Backend.outcomes` (`OutcomeRepository`), whose only construction path for
/// a `VerifiedOutcome` is `Domain.VerifiedOutcome.derive` — this view model
/// never builds one another way (Invariant 1, docs/PRODUCT.md), and it never
/// filters outcomes further by consent itself: `OutcomeRepository` already
/// excludes any engagement where consent is withheld.
@MainActor
@Observable
public final class ProofProfileViewModel {
    public private(set) var displayName = ""
    public private(set) var headline = ""
    public private(set) var verifications: [Verification] = []
    public private(set) var stats: ProofProfileStats = .zero
    public private(set) var journeys: [VerifiedJourney] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(backend: any Backend, professionalID: Identifier<Person>) {
        self.backend = backend
        self.professionalID = professionalID
    }

    /// Loads the profile header, aggregate stats, and verified journeys.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await backend.professionals.profile(forProfessional: professionalID)
            displayName = profile?.displayName ?? ""
            headline = profile?.headline ?? ""
            verifications = profile?.verifications ?? []

            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var allSessions: [Session] = []
            for engagement in engagements {
                allSessions.append(contentsOf: try await backend.sessions.fetchSessions(forEngagement: engagement.id))
            }
            stats = ProofProfileSummaries.stats(engagements: engagements, sessions: allSessions)

            let outcomes = try await backend.outcomes.outcomes(forProfessional: professionalID)
            journeys = ProofProfileSummaries.journeys(from: outcomes)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your proof profile. Pull to refresh to try again."
        }
    }
}
