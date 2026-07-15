import Domain
import Foundation

struct PaymentRow: SupabaseRow {
    let id: Identifier<Payment>
    let engagementID: Identifier<Engagement>
    let amountCents: Int
    let currency: String
    let status: PaymentStatus
    let platformFeeCents: Int
    let stripePaymentIntentID: String?
    let createdAt: Date

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case amountCents = "amount_cents"
        case currency
        case status
        case platformFeeCents = "platform_fee_cents"
        case stripePaymentIntentID = "stripe_payment_intent_id"
        case createdAt = "created_at"
    }

    init(domain: Payment) {
        id = domain.id
        engagementID = domain.engagementID
        amountCents = domain.amountCents
        currency = domain.currency
        status = domain.status
        platformFeeCents = domain.platformFeeCents
        stripePaymentIntentID = domain.stripePaymentIntentID
        createdAt = domain.createdAt
    }

    var toDomain: Payment {
        Payment(
            id: id,
            engagementID: engagementID,
            amountCents: amountCents,
            currency: currency,
            status: status,
            platformFeeCents: platformFeeCents,
            stripePaymentIntentID: stripePaymentIntentID,
            createdAt: createdAt
        )
    }
}
