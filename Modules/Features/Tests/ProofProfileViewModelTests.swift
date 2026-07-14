import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ProofProfileViewModel against seeded data")
@MainActor
struct ProofProfileViewModelTests {
    @Test("Proof Profile shows exactly the outcomes OutcomeRepository.outcomes(forProfessional:) yields")
    func journeysMatchDerivedOutcomesExactly() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let expectedOutcomes = try await backend.outcomes.outcomes(forProfessional: professional.id)

        let viewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await viewModel.load()

        #expect(viewModel.loadErrorMessage == nil)
        // At least 3 verified journeys, per the seeded fixture's design (see
        // InMemoryStore's SeededDataOutcomesTests) — and no more/fewer than
        // what `derive` actually yielded.
        #expect(expectedOutcomes.count >= 3)
        #expect(viewModel.journeys.count == expectedOutcomes.count)
        // `derive` mints a fresh random `id` on every call (see
        // `VerifiedOutcome.derive`), so two independent calls over the same
        // evidence never share `id`s — compare by evidentiary content
        // instead (engagement + metric + start/end values) to confirm the
        // view model surfaces the same underlying outcomes, not just the
        // same count.
        #expect(Set(viewModel.journeys.map { OutcomeSignature($0.outcome) }) == Set(expectedOutcomes.map { OutcomeSignature($0) }))

        // Every journey's copy is a formatted description of that same
        // outcome — journeys are never authored independently of `derive`'s
        // output (Invariant 1).
        for journey in viewModel.journeys {
            #expect(journey.description == ProofProfileSummaries.journeyDescription(for: journey.outcome))
        }
    }

    @Test("a seeded engagement with consent withheld contributes zero outcomes despite otherwise-qualifying activity")
    func consentOffEngagementIsExcluded() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)

        var verifiedAConsentOffCase = false
        for engagement in engagements {
            let consentGranted = try await backend.engagements.consent(for: engagement.id)
            guard !consentGranted, engagement.isEstablished else { continue }

            let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
            let payments = try await backend.payments.payments(forEngagement: engagement.id)
            let hasCompletedSession = sessions.contains { $0.status == .completed }
            let hasSucceededPayment = payments.contains { $0.status == .succeeded }
            guard hasCompletedSession, hasSucceededPayment else { continue }

            // This engagement satisfies every pillar except consent — a
            // faithful implementation must still yield zero outcomes for it.
            verifiedAConsentOffCase = true
            let outcomes = try await backend.outcomes.outcomes(forEngagement: engagement.id)
            #expect(outcomes.isEmpty)
        }

        #expect(verifiedAConsentOffCase, "expected a seeded engagement with withheld consent but otherwise-qualifying activity")

        // And the full Proof Profile for this professional contains no
        // journey rooted in that engagement.
        let viewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await viewModel.load()
        for engagement in engagements {
            let consentGranted = try await backend.engagements.consent(for: engagement.id)
            guard !consentGranted else { continue }
            #expect(!viewModel.journeys.contains { $0.outcome.engagementID == engagement.id })
        }
    }

    @Test("aggregate stats match a hand-computed pass over the same seeded engagements/sessions")
    func aggregateStatsMatchSeededData() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)

        var allSessions: [Session] = []
        for engagement in engagements {
            allSessions.append(contentsOf: try await backend.sessions.fetchSessions(forEngagement: engagement.id))
        }

        let expectedSessionsCompleted = allSessions.filter { $0.status == .completed }.count
        let expectedActiveClients = engagements.filter { $0.status == .active }.count
        let established = engagements.filter(\.isEstablished)
        let expectedRetention = established.isEmpty
            ? nil
            : Double(established.filter { $0.status != .ended }.count) / Double(established.count)

        let viewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await viewModel.load()

        #expect(viewModel.stats.sessionsCompleted == expectedSessionsCompleted)
        #expect(viewModel.stats.sessionsCompleted > 0)
        #expect(viewModel.stats.activeClients == expectedActiveClients)
        #expect(viewModel.stats.retentionRate == expectedRetention)
    }

    @Test("verification badges reflect the professional's profile")
    func verificationsLoadFromProfile() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let profile = try await backend.professionals.profile(forProfessional: professional.id)

        let viewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await viewModel.load()

        #expect(viewModel.displayName == profile?.displayName)
        #expect(viewModel.verifications.count == profile?.verifications.count)
        #expect(viewModel.verifications.contains { $0.status == .verified })
    }

    @Test("an engagement-less professional sees empty journeys/stats, not an error")
    func emptyProfessionalSeesEmptyProofProfile() async {
        let backend = InMemoryStore.seeded()
        let viewModel = ProofProfileViewModel(backend: backend, professionalID: Identifier(), paymentsMode: .live)

        await viewModel.load()

        #expect(viewModel.journeys.isEmpty)
        #expect(viewModel.stats.sessionsCompleted == 0)
        #expect(viewModel.stats.activeClients == 0)
        #expect(viewModel.stats.retentionRate == nil)
        #expect(viewModel.loadErrorMessage == nil)
    }

    // MARK: - .free mode: Tracked results, never Verified

    @Test(".free mode surfaces Tracked results (not Verified journeys) — a superset of what .live derives, since Tracked drops only the payment pillar")
    func freeModeSurfacesTrackedNotVerified() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let liveViewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await liveViewModel.load()
        // Sanity: this professional genuinely has Verified journeys in
        // `.live` mode — otherwise this test wouldn't be isolating the
        // mode's effect.
        #expect(!liveViewModel.journeys.isEmpty)

        let freeViewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .free)
        await freeViewModel.load()

        #expect(freeViewModel.loadErrorMessage == nil)
        // No `VerifiedOutcome` is ever surfaced in `.free` mode.
        #expect(freeViewModel.journeys.isEmpty)
        #expect(!freeViewModel.trackedJourneys.isEmpty)

        // Every engagement/metric pair that derived a Verified journey in
        // `.live` mode also appears as a Tracked result in `.free` mode:
        // Tracked requires everything Verified does except a succeeded
        // payment, so it can never be a strict subset.
        let trackedKeys = Set(freeViewModel.trackedJourneys.map { TrackedKey(engagementID: $0.engagementID, metric: $0.metric) })
        for journey in liveViewModel.journeys {
            #expect(trackedKeys.contains(TrackedKey(engagementID: journey.outcome.engagementID, metric: journey.outcome.metric)))
        }

        // Tracked copy reuses the exact same phrasing helper Verified does
        // (`ProofProfileSummaries.journeyDescription`), so a matching
        // engagement/metric pair's description is byte-for-byte identical
        // across modes.
        for journey in liveViewModel.journeys {
            let matchingTracked = freeViewModel.trackedJourneys.first {
                $0.engagementID == journey.outcome.engagementID && $0.metric == journey.outcome.metric
            }
            #expect(matchingTracked?.description == journey.description)
        }
    }

    @Test("a seeded engagement with consent withheld contributes zero Tracked results, despite otherwise-qualifying activity")
    func freeModeConsentOffEngagementIsExcludedFromTracked() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)

        var foundConsentOffCase = false
        for engagement in engagements {
            let consentGranted = try await backend.engagements.consent(for: engagement.id)
            guard !consentGranted, engagement.isEstablished else { continue }
            let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
            guard sessions.contains(where: { $0.status == .completed }) else { continue }
            foundConsentOffCase = true
        }
        #expect(foundConsentOffCase, "expected a seeded engagement with withheld consent but otherwise-qualifying activity")

        let viewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .free)
        await viewModel.load()

        for engagement in engagements {
            let consentGranted = try await backend.engagements.consent(for: engagement.id)
            guard !consentGranted else { continue }
            #expect(!viewModel.trackedJourneys.contains { $0.engagementID == engagement.id })
        }
    }

    @Test("flipping paymentsMode on the same professional/backend restores Verified and clears Tracked, in both directions")
    func flippingPaymentsModeSwapsJourneySurfaces() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let freeViewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .free)
        await freeViewModel.load()
        #expect(freeViewModel.journeys.isEmpty)
        #expect(!freeViewModel.trackedJourneys.isEmpty)

        let liveViewModel = ProofProfileViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live)
        await liveViewModel.load()
        #expect(!liveViewModel.journeys.isEmpty)
        #expect(liveViewModel.trackedJourneys.isEmpty)
    }
}

/// Identifies a `TrackedJourney` (or an outcome coerced to the same shape)
/// by engagement + metric, for cross-mode comparisons that don't care about
/// exact copy/id.
private struct TrackedKey: Hashable {
    let engagementID: Identifier<Engagement>
    let metric: MetricKind
}

/// Identifies a `VerifiedOutcome` by its evidentiary content rather than its
/// `id` — `derive` mints a fresh random `id` on every call (see
/// `VerifiedOutcome.derive`), so `id` alone can't be used to confirm two
/// independently-derived outcome sets describe the same underlying journeys.
private struct OutcomeSignature: Hashable {
    let engagementID: Identifier<Engagement>
    let metric: MetricKind
    let start: MetricValue
    let end: MetricValue

    init(_ outcome: VerifiedOutcome) {
        engagementID = outcome.engagementID
        metric = outcome.metric
        start = outcome.start
        end = outcome.end
    }
}
