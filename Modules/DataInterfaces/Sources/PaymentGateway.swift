import Domain

/// Stripe-agnostic payment processing for a coaching engagement: charge a
/// client and refund a previous charge.
///
/// Kept independent of any concrete payment provider on purpose — no Stripe
/// types, secret keys, or PaymentIntent client secrets ever appear in this
/// protocol, and `Payment.stripePaymentIntentID` stays `nil` for every mock
/// implementation. See docs/BACKEND.md for the real plan (Stripe Connect
/// Express, server-created PaymentIntents via Supabase Edge Functions) this
/// protocol stands in for until that lands (~Prompt 14).
///
/// Platform fee: computed by the adapter from a fixed, documented
/// percentage of the charged amount, never passed in by the caller — see
/// `MockPaymentGateway`'s (`InMemoryBackend+PaymentGateway.swift`)
/// `platformFeeBasisPoints`. A future Stripe-backed adapter would compute
/// the same fee and pass it as Stripe's `application_fee_amount` on the
/// server-created PaymentIntent, so `Features` callers never change.
///
/// `Backend` vends this as `var paymentGateway: any PaymentGateway`.
public protocol PaymentGateway: Sendable {
    /// Charges `amountCents` (in `currency`, e.g. "USD") to close out a
    /// session or package for `engagementID`, persists the resulting
    /// `.succeeded` `Payment`, and returns it.
    func charge(
        engagementID: Identifier<Engagement>,
        amountCents: Int,
        currency: String
    ) async throws -> Payment

    /// Refunds a previously-charged payment, persists the updated
    /// `.refunded` copy, and returns it. Throws if no payment exists for
    /// `paymentID`.
    func refund(paymentID: Identifier<Payment>) async throws -> Payment
}
