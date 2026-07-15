#if DEBUG

import DataInterfaces
import Domain

/// The demo control panel's live payment-outcome control: forces every
/// subsequent `DemoPaymentGateway.charge` to succeed, succeed-then-refund,
/// or fail outright — deterministic exercise of the charge/refund/decline
/// UI without touching `Domain`, `PaymentGateway`'s semantics, or the mock
/// gateway's fee math.
///
/// An `actor` (not a `@MainActor @Observable` class): `DemoPaymentGateway`
/// must stay `Sendable` (it conforms to `PaymentGateway: Sendable`), and a
/// `@MainActor`-isolated class is not itself `Sendable` — the same
/// constraint documented in docs/BUILD_STATUS.md for `PaymentsMode`. An
/// actor is `Sendable` unconditionally, and every `PaymentGateway` method is
/// already `async`, so awaiting into it costs nothing extra at the call
/// site.
actor DemoPaymentOutcomeController {
    enum Outcome: String, CaseIterable, Identifiable, Sendable {
        case succeed
        case refund
        case fail

        var id: String { rawValue }

        var title: String {
            switch self {
            case .succeed: "Succeed"
            case .refund: "Succeed, then refund"
            case .fail: "Fail"
            }
        }
    }

    private(set) var outcome: Outcome = .succeed

    func setOutcome(_ newOutcome: Outcome) {
        outcome = newOutcome
    }
}

/// Wraps a real `PaymentGateway` (the active scenario's backend) and
/// applies `DemoPaymentOutcomeController`'s current outcome to every
/// charge — still only ever calling through to the wrapped gateway's own
/// `charge`/`refund`, never constructing a `Payment` by hand.
struct DemoPaymentGateway: PaymentGateway {
    enum SimulatedError: Error, Sendable {
        case simulatedFailure
    }

    let wrapped: any PaymentGateway
    let controller: DemoPaymentOutcomeController

    func charge(
        engagementID: Identifier<Engagement>,
        amountCents: Int,
        currency: String
    ) async throws -> Payment {
        switch await controller.outcome {
        case .succeed:
            return try await wrapped.charge(engagementID: engagementID, amountCents: amountCents, currency: currency)
        case .refund:
            let payment = try await wrapped.charge(engagementID: engagementID, amountCents: amountCents, currency: currency)
            return try await wrapped.refund(paymentID: payment.id)
        case .fail:
            throw SimulatedError.simulatedFailure
        }
    }

    func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        try await wrapped.refund(paymentID: paymentID)
    }
}

#endif
