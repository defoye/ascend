import DataInterfaces
import Domain
import Foundation
import Observation

/// A single payment joined with the display name of the client it belongs
/// to, for `PaymentHistoryView`'s list.
public struct PaymentHistoryItem: Sendable, Identifiable, Equatable {
    public let payment: Payment
    public let clientName: String

    public init(payment: Payment, clientName: String) {
        self.payment = payment
        self.clientName = clientName
    }

    public var id: Identifier<Payment> { payment.id }

    /// The coach's net for a `.succeeded` payment (`amountCents -
    /// platformFeeCents`, per docs/DATA_MODEL.md); `nil` for any other
    /// status, since nothing was actually collected.
    public var netCents: Int? {
        payment.status == .succeeded ? payment.amountCents - payment.platformFeeCents : nil
    }
}

/// View model for the coach's full payment history across every
/// engagement: every `Payment` joined with its client's name, newest first,
/// plus an all-time platform-fee-aware revenue summary.
///
/// Revenue math is never reimplemented here — it reuses
/// `TodaySummaries.revenueSummary`, the same function the Today dashboard
/// uses, just with an effectively unbounded window instead of the
/// dashboard's trailing 30 days.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class PaymentHistoryViewModel {
    /// `TodaySummaries.revenueSummary`'s window is "trailing `windowDays`
    /// days ending at `now`" — there's no separate "all time" mode. A
    /// ~100-year window is effectively unbounded for any payment this app
    /// will ever hold, without changing that function's contract.
    private static let allTimeWindowDays = 36_500

    public private(set) var items: [PaymentHistoryItem] = []
    public private(set) var revenueSummary: RevenueSummary = .zero
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
    }

    /// Loads every engagement for `professionalID`, joins each engagement's
    /// payments with the client's name, and rolls everything into an
    /// all-time `revenueSummary`.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var allItems: [PaymentHistoryItem] = []
            var allPayments: [Payment] = []

            for engagement in engagements {
                let client = try await backend.people.get(engagement.clientID)
                let clientName = client?.displayName ?? "Client"
                let payments = try await backend.payments.payments(forEngagement: engagement.id)
                allPayments.append(contentsOf: payments)
                allItems.append(contentsOf: payments.map { PaymentHistoryItem(payment: $0, clientName: clientName) })
            }

            items = allItems.sorted { $0.payment.createdAt > $1.payment.createdAt }
            revenueSummary = TodaySummaries.revenueSummary(from: allPayments, now: clock(), windowDays: Self.allTimeWindowDays)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your payments. Pull to refresh to try again."
        }
    }
}
