import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

@Suite("Seeded MockData -> VerifiedOutcome")
struct SeededDataOutcomesTests {
    @Test("InMemoryBackend.seeded() yields at least 3 VerifiedOutcomes for the seeded professional")
    func seededDataYieldsAtLeastThreeOutcomes() async throws {
        let backend = InMemoryBackend.seeded()
        let outcomes = try await backend.outcomes.outcomes(forProfessional: MockData.professionalPersonID)
        #expect(outcomes.count >= 3)
    }

    @Test("outcomes are only derived for engagements with full evidence (pending/no-consent/insufficient-progress clients excluded)")
    func onlyFullyVerifiedEngagementsProduceOutcomes() async throws {
        let backend = InMemoryBackend.seeded()

        // Client 0 (pending): not established, must derive nothing.
        let pendingOutcomes = try await backend.outcomes.outcomes(forEngagement: MockData.engagementID(0))
        #expect(pendingOutcomes.isEmpty)

        // Client 3 (only one progress point): must derive nothing.
        let insufficientProgressOutcomes = try await backend.outcomes.outcomes(forEngagement: MockData.engagementID(3))
        #expect(insufficientProgressOutcomes.isEmpty)

        // Client 6 (consent withheld despite full activity): must derive nothing.
        let noConsentOutcomes = try await backend.outcomes.outcomes(forEngagement: MockData.engagementID(6))
        #expect(noConsentOutcomes.isEmpty)

        // Client 1 (active, bodyweight progress, consented): must derive an outcome.
        let activeOutcomes = try await backend.outcomes.outcomes(forEngagement: MockData.engagementID(1))
        #expect(activeOutcomes.count == 1)
        #expect(activeOutcomes.first?.metric == .bodyweight)
        #expect(activeOutcomes.first?.isImprovement == true)
    }

    @Test("seeded people: one professional owner plus eight clients")
    func seededPeopleExist() async throws {
        let backend = InMemoryBackend.seeded()
        let people = try await backend.people.list()
        #expect(people.count == 9)

        let profile = try await backend.professionals.profile(forProfessional: MockData.professionalPersonID)
        #expect(profile != nil)
        #expect(profile?.services.isEmpty == false)
    }

    @Test("seeded engagements span every EngagementStatus")
    func seededEngagementsSpanEveryStatus() async throws {
        let backend = InMemoryBackend.seeded()
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: MockData.professionalPersonID)
        let statuses = Set(engagements.map(\.status))
        #expect(statuses == Set([.pending, .active, .paused, .completed, .ended]))
    }
}
