import DataInterfaces
import Domain
import Foundation

/// Mock implementation of `PaymentGateway`: every charge succeeds
/// immediately (no real card entry, no network, no Stripe types), and the
/// platform fee is computed from a fixed, documented percentage rather than
/// passed in by the caller (see `PaymentGateway`'s doc comment).
extension InMemoryBackend: PaymentGateway {
    /// 10% of the charged amount (1000 basis points), rounded down to the
    /// nearest cent — mirrors the fee convention already baked into seeded
    /// fixture payments (`MockData.mockPayment`, `amountCents / 10`), so
    /// mock charges and seeded historical payments stay fee-consistent.
    static let platformFeeBasisPoints = 1_000

    public func charge(
        engagementID: Identifier<Engagement>,
        amountCents: Int,
        currency: String
    ) async throws -> Payment {
        let platformFeeCents = amountCents * Self.platformFeeBasisPoints / 10_000
        let payment = Payment(
            id: Identifier(),
            engagementID: engagementID,
            amountCents: amountCents,
            currency: currency,
            status: .succeeded,
            platformFeeCents: platformFeeCents,
            stripePaymentIntentID: nil,
            createdAt: Date()
        )
        paymentsByID[payment.id] = payment
        return payment
    }

    public func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        guard let existing = paymentsByID[paymentID] else { throw InMemoryStoreError.notFound }
        let refunded = Payment(
            id: existing.id,
            engagementID: existing.engagementID,
            amountCents: existing.amountCents,
            currency: existing.currency,
            status: .refunded,
            platformFeeCents: existing.platformFeeCents,
            stripePaymentIntentID: existing.stripePaymentIntentID,
            createdAt: existing.createdAt
        )
        paymentsByID[paymentID] = refunded
        return refunded
    }
}
