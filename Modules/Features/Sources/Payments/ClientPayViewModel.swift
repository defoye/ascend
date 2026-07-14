import DataInterfaces
import Domain
import Foundation
import Observation

/// STUB: a minimal client-side "pay for a service" flow. No real card
/// entry — the mock gateway succeeds immediately, and there's no consumer
/// app root to reach this from yet. This exists to prove the client side of
/// `PaymentGateway` works end-to-end; a real card-entry + webhook-backed
/// flow requires the server and lands with the Stripe integration (see
/// docs/BACKEND.md, docs/ROADMAP.md Prompt 14).
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ClientPayViewModel {
    public let service: Service
    public private(set) var isPaying = false
    public private(set) var payErrorMessage: String?
    public private(set) var completedPayment: Payment?

    private let backend: any Backend
    private let engagementID: Identifier<Engagement>

    public init(backend: any Backend, engagementID: Identifier<Engagement>, service: Service) {
        self.backend = backend
        self.engagementID = engagementID
        self.service = service
    }

    public var isPaid: Bool { completedPayment?.status == .succeeded }

    /// Charges `service.priceCents` through `Backend.paymentGateway`; the
    /// mock succeeds immediately and `completedPayment` reflects the
    /// resulting `.succeeded` state.
    @discardableResult
    public func pay() async -> Payment? {
        isPaying = true
        defer { isPaying = false }
        do {
            let payment = try await backend.paymentGateway.charge(
                engagementID: engagementID,
                amountCents: service.priceCents,
                currency: service.currency
            )
            completedPayment = payment
            payErrorMessage = nil
            return payment
        } catch {
            payErrorMessage = "Couldn't process payment. Try again."
            return nil
        }
    }
}
