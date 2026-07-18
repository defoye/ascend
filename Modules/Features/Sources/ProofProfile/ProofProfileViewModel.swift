import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's "Proof Profile" screen: verification badges,
/// aggregate practice stats, and — depending on `paymentsMode` — either
/// anonymized verified journeys or anonymized Tracked results.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md) — never a
/// concrete backend adapter. While `paymentsMode` is `.live`, journeys come
/// exclusively from `Backend.outcomes` (`OutcomeRepository`), whose only
/// construction path for a `VerifiedOutcome` is `Domain.VerifiedOutcome.derive`
/// — this view model never builds one another way (Invariant 1,
/// docs/PRODUCT.md), and it never filters outcomes further by consent
/// itself: `OutcomeRepository` already excludes any engagement where consent
/// is withheld. While `paymentsMode` is `.free`, no `VerifiedOutcome` is ever
/// surfaced — `trackedJourneys` instead comes from `TrackedJourneySummaries`,
/// a pure function that never constructs a `VerifiedOutcome` and mirrors
/// `derive`'s non-payment pillars, including its consent gate (Option B, see
/// docs/BACKEND.md "PaymentsMode: free-first rollout").
@MainActor
@Observable
public final class ProofProfileViewModel {
    public private(set) var displayName = ""
    public private(set) var headline = ""
    public private(set) var verifications: [Verification] = []
    public private(set) var stats: ProofProfileStats = .zero
    /// Populated only while `paymentsMode == .live`; empty while `.free`.
    public private(set) var journeys: [VerifiedJourney] = []
    /// Populated only while `paymentsMode == .free`; empty while `.live`.
    public private(set) var trackedJourneys: [TrackedJourney] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    public let paymentsMode: PaymentsMode

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(backend: any Backend, professionalID: Identifier<Person>, paymentsMode: PaymentsMode = .live) {
        self.backend = backend
        self.professionalID = professionalID
        self.paymentsMode = paymentsMode
    }

    /// Loads the profile header, aggregate stats, and (mode-dependent)
    /// verified journeys or Tracked results.
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

            switch paymentsMode {
            case .live:
                let outcomes = try await backend.outcomes.outcomes(forProfessional: professionalID)
                journeys = ProofProfileSummaries.journeys(from: outcomes)
                trackedJourneys = []
            case .free:
                trackedJourneys = try await loadTrackedJourneys(engagements: engagements)
                journeys = []
            }
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your proof profile. Pull to refresh to try again."
        }
    }

    /// Gathers each engagement's Tracked-eligibility evidence (sessions,
    /// progress, consent — no payments) and derives Tracked journeys purely
    /// via `TrackedJourneySummaries`.
    private func loadTrackedJourneys(engagements: [Engagement]) async throws -> [TrackedJourney] {
        var evidence: [TrackedEngagementEvidence] = []
        for engagement in engagements {
            let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
            let progress = try await backend.progress.fetchEntries(forEngagement: engagement.id)
            let consentGranted = try await backend.engagements.consent(for: engagement.id)
            evidence.append(
                TrackedEngagementEvidence(
                    engagement: engagement,
                    progress: progress,
                    completedSessions: sessions.filter { $0.status == .completed },
                    clientConsent: consentGranted
                )
            )
        }
        return TrackedJourneySummaries.trackedJourneys(from: evidence)
    }
}
