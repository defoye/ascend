import DataInterfaces
import Domain
import Foundation

/// A placeholder `PaymentGateway`: writes a real `.succeeded` `Payment` row
/// to Postgres (unlike `DataInterfaces.NoOpPaymentGateway`, which always
/// throws), computing the platform fee the same way `InMemoryBackend`'s
/// `MockPaymentGateway` does. No Stripe types, network calls, or secret keys
/// are involved — this exists only so `Backend.paymentGateway` vends
/// something real if `PaymentsMode` is ever `.live` against
/// `SupabaseBackend` before Prompt 14 (Stripe Connect Express via Supabase
/// Edge Functions — see docs/BACKEND.md) lands. In practice launch ships
/// with `PaymentsMode.free` (see docs/BUILD_STATUS.md "free first" rollout),
/// so `PaymentsModeBackend` substitutes `NoOpPaymentGateway` ahead of this
/// ever being reached.
extension SupabaseBackend: PaymentGateway {
    /// Mirrors `InMemoryBackend`'s documented convention exactly: 10% of the
    /// charged amount, rounded down to the nearest cent.
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
        try await paymentsTable.upsert(PaymentRow(domain: payment))
        return payment
    }

    public func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        guard let existing = try await paymentsTable.fetchOne(id: paymentID.rawValue) else {
            throw SupabaseBackendError.notFound
        }
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
        try await paymentsTable.upsert(PaymentRow(domain: refunded))
        return refunded
    }
}
