import Foundation

/// A single payment made within an `Engagement`.
public struct Payment: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<Payment>
    public let engagementID: Identifier<Engagement>
    public let amountCents: Int
    public let currency: String
    public let status: PaymentStatus
    public let platformFeeCents: Int
    public let stripePaymentIntentID: String?

    public init(
        id: Identifier<Payment>,
        engagementID: Identifier<Engagement>,
        amountCents: Int,
        currency: String,
        status: PaymentStatus,
        platformFeeCents: Int,
        stripePaymentIntentID: String?
    ) {
        self.id = id
        self.engagementID = engagementID
        self.amountCents = amountCents
        self.currency = currency
        self.status = status
        self.platformFeeCents = platformFeeCents
        self.stripePaymentIntentID = stripePaymentIntentID
    }
}
