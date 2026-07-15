import DataInterfaces
import Domain
import InMemoryStore
import Testing

@testable import Ascend

@Suite("DemoPaymentOutcomeController / DemoPaymentGateway")
struct DemoPaymentGatewayTests {
    @Test("succeed outcome forwards straight to the wrapped gateway's charge")
    func succeedForwardsCharge() async throws {
        let wrapped = InMemoryBackend()
        let controller = DemoPaymentOutcomeController()
        let gateway = DemoPaymentGateway(wrapped: wrapped, controller: controller)
        let engagementID = Identifier<Engagement>()

        let payment = try await gateway.charge(engagementID: engagementID, amountCents: 10_000, currency: "USD")

        #expect(payment.status == .succeeded)
    }

    @Test("refund outcome charges then immediately refunds through the wrapped gateway")
    func refundOutcomeRefundsAfterCharging() async throws {
        let wrapped = InMemoryBackend()
        let controller = DemoPaymentOutcomeController()
        await controller.setOutcome(.refund)
        let gateway = DemoPaymentGateway(wrapped: wrapped, controller: controller)
        let engagementID = Identifier<Engagement>()

        let payment = try await gateway.charge(engagementID: engagementID, amountCents: 10_000, currency: "USD")

        #expect(payment.status == .refunded)
    }

    @Test("fail outcome throws without ever creating a payment on the wrapped gateway")
    func failOutcomeThrows() async throws {
        let wrapped = InMemoryBackend()
        let controller = DemoPaymentOutcomeController()
        await controller.setOutcome(.fail)
        let gateway = DemoPaymentGateway(wrapped: wrapped, controller: controller)
        let engagementID = Identifier<Engagement>()

        await #expect(throws: DemoPaymentGateway.SimulatedError.self) {
            try await gateway.charge(engagementID: engagementID, amountCents: 10_000, currency: "USD")
        }

        let payments = try await wrapped.payments.payments(forEngagement: engagementID)
        #expect(payments.isEmpty)
    }

    @Test("controller outcome round-trips through setOutcome")
    func controllerOutcomeRoundTrips() async {
        let controller = DemoPaymentOutcomeController()
        #expect(await controller.outcome == .succeed)
        await controller.setOutcome(.fail)
        #expect(await controller.outcome == .fail)
    }
}
