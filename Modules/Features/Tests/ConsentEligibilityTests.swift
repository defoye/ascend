import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

/// The Invariant-1 proof (docs/PRODUCT.md): toggling a client's
/// outcome-sharing consent through `ConsentViewModel` — the exact surface
/// `ConsentView` exposes on the client's "Me" tab — genuinely flips whether
/// `Domain.VerifiedOutcome.derive` can yield an outcome for their
/// engagement, in both directions. Consent is never a display-only flag.
@Suite("ConsentViewModel toggling flows to VerifiedOutcome derivation eligibility")
@MainActor
struct ConsentEligibilityTests {
    /// Morgan Chen's engagement: active, an assigned program, completed
    /// sessions, succeeded payments, and 2+ time-separated `bodyweight`
    /// progress points — every pillar of `VerifiedOutcome.derive` except
    /// consent is already satisfied by the seeded fixture (see
    /// `MockData+Engagements.swift`), so consent is the only variable this
    /// test needs to flip.
    private func morganChenEngagementID(backend: InMemoryBackend) async throws -> Identifier<Engagement> {
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morganChen.id).first)
        return engagement.id
    }

    @Test("consent OFF yields zero VerifiedOutcomes even though every other pillar is satisfied")
    func consentOffYieldsNoOutcomes() async throws {
        let backend = InMemoryStore.seeded()
        let engagementID = try await morganChenEngagementID(backend: backend)

        // Sanity: this engagement genuinely derives when consent is on —
        // otherwise this test wouldn't be isolating the consent pillar.
        let baseline = try await backend.outcomes.outcomes(forEngagement: engagementID)
        #expect(!baseline.isEmpty)

        let viewModel = ConsentViewModel(backend: backend, engagementID: engagementID)
        await viewModel.load()
        #expect(viewModel.isGranted) // seeded consent starts granted for this engagement

        await viewModel.setGranted(false)
        #expect(!viewModel.isGranted)

        let outcomesAfterRevoking = try await backend.outcomes.outcomes(forEngagement: engagementID)
        #expect(outcomesAfterRevoking.isEmpty)
    }

    @Test("re-granting consent makes the outcome derivable again, with every other pillar untouched")
    func reGrantingConsentRestoresOutcomeEligibility() async throws {
        let backend = InMemoryStore.seeded()
        let engagementID = try await morganChenEngagementID(backend: backend)

        let viewModel = ConsentViewModel(backend: backend, engagementID: engagementID)
        await viewModel.load()

        await viewModel.setGranted(false)
        let outcomesWhileRevoked = try await backend.outcomes.outcomes(forEngagement: engagementID)
        #expect(outcomesWhileRevoked.isEmpty)

        await viewModel.setGranted(true)
        #expect(viewModel.isGranted)

        let outcomesAfterReGranting = try await backend.outcomes.outcomes(forEngagement: engagementID)
        #expect(!outcomesAfterReGranting.isEmpty)
        #expect(outcomesAfterReGranting.allSatisfy { $0.basis.isFullyVerified })
    }
}
