import DataInterfaces
import Domain
import Testing

@testable import Ascend

@Suite("DemoScenarioFactory")
struct DemoScenarioFactoryTests {
    @Test("richDemo resolves the seeded professional with existing engagements")
    func richDemoResolvesSeededProfessional() async throws {
        let bundle = await DemoScenarioFactory.makeBundle(for: .richDemo)
        let engagements = try await bundle.backend.engagements.fetchEngagements(forProfessional: bundle.professionalID)
        #expect(!engagements.isEmpty)
    }

    @Test("showcase guarantees at least one refunded payment across the professional's engagements")
    func showcaseGuaranteesRefundedPayment() async throws {
        let bundle = await DemoScenarioFactory.makeBundle(for: .showcase)
        let engagements = try await bundle.backend.engagements.fetchEngagements(forProfessional: bundle.professionalID)

        var foundRefund = false
        for engagement in engagements {
            let payments = try await bundle.backend.payments.payments(forEngagement: engagement.id)
            if payments.contains(where: { $0.status == .refunded }) {
                foundRefund = true
                break
            }
        }
        #expect(foundRefund)
    }

    @Test("emptyCoach starts with zero engagements and an upserted professional profile")
    func emptyCoachStartsEmpty() async throws {
        let bundle = await DemoScenarioFactory.makeBundle(for: .emptyCoach)
        let engagements = try await bundle.backend.engagements.fetchEngagements(forProfessional: bundle.professionalID)
        #expect(engagements.isEmpty)

        let profile = try await bundle.backend.professionals.profile(forProfessional: bundle.professionalID)
        #expect(profile != nil)
    }

    @Test("errorStates resolves the same seeded professional as richDemo but every subsequent repository read throws")
    func errorStatesThrowsOnReads() async throws {
        let richDemo = await DemoScenarioFactory.makeBundle(for: .richDemo)
        let errorStates = await DemoScenarioFactory.makeBundle(for: .errorStates)
        #expect(errorStates.professionalID == richDemo.professionalID)

        await #expect(throws: (any Error).self) {
            try await errorStates.backend.engagements.fetchEngagements(forProfessional: errorStates.professionalID)
        }
    }
}
