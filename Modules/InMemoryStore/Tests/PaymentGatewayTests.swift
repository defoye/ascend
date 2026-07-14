import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

@Suite("InMemoryBackend as PaymentGateway")
struct PaymentGatewayTests {
    @Test("charge writes a succeeded Payment retrievable via the payment repository for that engagement")
    func chargeWritesSucceededPayment() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()

        let charged = try await backend.paymentGateway.charge(engagementID: engagementID, amountCents: 10_000, currency: "USD")

        #expect(charged.status == .succeeded)
        #expect(charged.engagementID == engagementID)
        #expect(charged.amountCents == 10_000)
        #expect(charged.currency == "USD")
        #expect(charged.stripePaymentIntentID == nil)
        // 10% platform fee (see InMemoryBackend+PaymentGateway.swift).
        #expect(charged.platformFeeCents == 1_000)

        let fetched = try await backend.payments.payments(forEngagement: engagementID)
        #expect(fetched == [charged])
    }

    @Test("refund flips a charged payment to .refunded and persists the change")
    func chargeThenRefundYieldsRefundedPayment() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()

        let charged = try await backend.paymentGateway.charge(engagementID: engagementID, amountCents: 20_000, currency: "USD")
        #expect(charged.status == .succeeded)

        let refunded = try await backend.paymentGateway.refund(paymentID: charged.id)

        #expect(refunded.id == charged.id)
        #expect(refunded.status == .refunded)
        #expect(refunded.amountCents == charged.amountCents)
        #expect(refunded.platformFeeCents == charged.platformFeeCents)

        let fetched = try await backend.payments.payments(forEngagement: engagementID)
        #expect(fetched == [refunded])
    }

    @Test("refund of an unknown payment id throws")
    func refundUnknownThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.paymentGateway.refund(paymentID: Identifier())
        }
    }
}
