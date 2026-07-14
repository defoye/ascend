import DataInterfaces
import Domain
import Foundation
import Observation

/// A minimal engagement option for `ChargeClientViewModel`'s client picker —
/// just enough to label a row, not the full `ClientRosterItem` from Clients.
public struct ChargeableEngagement: Sendable, Identifiable, Equatable {
    public let engagementID: Identifier<Engagement>
    public let clientName: String

    public init(engagementID: Identifier<Engagement>, clientName: String) {
        self.engagementID = engagementID
        self.clientName = clientName
    }

    public var id: Identifier<Engagement> { engagementID }
}

/// View model for charging a client for a session or package: pick which
/// engagement to bill, then pick (via one of the coach's own `Service`
/// prices) or type an amount, and charge it through `Backend.paymentGateway`.
///
/// The concrete charge/platform-fee logic (mock today, Stripe-backed later)
/// lives entirely behind `PaymentGateway` (see docs/BACKEND.md) — this view
/// model never computes a platform fee itself, it just supplies the gross
/// amount to charge.
@MainActor
@Observable
public final class ChargeClientViewModel {
    public private(set) var engagementOptions: [ChargeableEngagement] = []
    public private(set) var services: [Service] = []
    public var selectedEngagementID: Identifier<Engagement>?
    /// Bound to the amount field, in whole currency units (e.g. dollars) as
    /// display text.
    public var amountText = ""
    public private(set) var isLoading = false
    public private(set) var isCharging = false
    public private(set) var loadErrorMessage: String?
    public private(set) var chargeErrorMessage: String?
    public private(set) var lastCharge: Payment?

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let currency: String

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        preselectedEngagementID: Identifier<Engagement>? = nil,
        currency: String = "USD"
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.currency = currency
        selectedEngagementID = preselectedEngagementID
    }

    /// Whether an engagement is picked and `amountText` parses to a
    /// positive number — the "Charge" button's enabled condition.
    public var isValid: Bool {
        guard selectedEngagementID != nil, let dollars = Double(amountText) else { return false }
        return dollars > 0
    }

    /// Loads the professional's clients (to bill) and services (for
    /// quick-select amount chips).
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var options: [ChargeableEngagement] = []
            for engagement in engagements {
                let client = try await backend.people.get(engagement.clientID)
                options.append(ChargeableEngagement(engagementID: engagement.id, clientName: client?.displayName ?? "Client"))
            }
            engagementOptions = options.sorted { $0.clientName < $1.clientName }
            if selectedEngagementID == nil {
                selectedEngagementID = engagementOptions.first?.engagementID
            }
            services = try await backend.professionals.profile(forProfessional: professionalID)?.services ?? []
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your clients. Pull to refresh to try again."
        }
    }

    /// Sets `amountText` from a tapped service's price, in dollars.
    public func selectService(_ service: Service) {
        amountText = Self.displayString(forCents: service.priceCents)
    }

    /// Charges the selected engagement for the parsed `amountText` through
    /// `PaymentGateway.charge(_:)`; the resulting `.succeeded` `Payment` is
    /// persisted by the gateway itself, not this view model.
    @discardableResult
    public func charge() async -> Payment? {
        guard let engagementID = selectedEngagementID, let dollars = Double(amountText), dollars > 0 else { return nil }
        isCharging = true
        defer { isCharging = false }

        let amountCents = Int((dollars * 100).rounded())
        do {
            let payment = try await backend.paymentGateway.charge(
                engagementID: engagementID,
                amountCents: amountCents,
                currency: currency
            )
            lastCharge = payment
            chargeErrorMessage = nil
            return payment
        } catch {
            chargeErrorMessage = "Couldn't charge this client. Try again."
            return nil
        }
    }

    static func displayString(forCents cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }
}
