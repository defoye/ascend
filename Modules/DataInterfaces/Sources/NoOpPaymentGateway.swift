import Domain

/// A `PaymentGateway` that never succeeds — the stand-in the composition
/// root wires in when `PaymentsMode` is `.free` (see `PaymentsMode`,
/// docs/BUILD_STATUS.md "Rollout strategy — free first, monetize later").
///
/// The free phase's UI hides every charge/pay entry point, so in practice
/// nothing calls this; it exists so `Backend.paymentGateway` always vends a
/// real, safe value instead of forcing every adapter to special-case a `nil`
/// gateway. If a code path is ever reached unexpectedly while payments are
/// off, it fails loudly (throws) rather than silently pretending to charge a
/// card.
public struct NoOpPaymentGateway: PaymentGateway, Sendable {
    /// Thrown by every method: payments are not enabled in this build/mode.
    public enum GatewayError: Error, Sendable, Equatable {
        case paymentsNotEnabled
    }

    public init() {}

    public func charge(
        engagementID: Identifier<Engagement>,
        amountCents: Int,
        currency: String
    ) async throws -> Payment {
        throw GatewayError.paymentsNotEnabled
    }

    public func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        throw GatewayError.paymentsNotEnabled
    }
}
