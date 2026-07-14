import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("Payments feature view models")
@MainActor
struct PaymentsViewModelTests {
    @Test("ChargeClientViewModel loads clients + services, then charges through the gateway")
    func chargeClientViewModelChargesThroughGateway() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = ChargeClientViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()

        #expect(!viewModel.engagementOptions.isEmpty)
        #expect(!viewModel.services.isEmpty)
        #expect(viewModel.selectedEngagementID != nil)

        let service = try #require(viewModel.services.first)
        viewModel.selectService(service)
        #expect(viewModel.amountText == ChargeClientViewModel.displayString(forCents: service.priceCents))
        #expect(viewModel.isValid)

        let charged = try #require(await viewModel.charge())
        #expect(charged.status == .succeeded)
        #expect(charged.amountCents == service.priceCents)

        let engagementID = try #require(viewModel.selectedEngagementID)
        let persisted = try await backend.payments.payments(forEngagement: engagementID)
        #expect(persisted.contains(charged))
    }

    @Test("ServicePricingViewModel loads and saves updated service prices")
    func servicePricingViewModelSavesPrices() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = ServicePricingViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()

        let service = try #require(viewModel.services.first)
        viewModel.draftPrices[service.id] = "199.00"

        let saved = await viewModel.save()
        #expect(saved)
        #expect(viewModel.services.first { $0.id == service.id }?.priceCents == 19_900)

        let persistedProfile = try await backend.professionals.profile(forProfessional: professional.id)
        #expect(persistedProfile?.services.first { $0.id == service.id }?.priceCents == 19_900)
    }

    @Test("PaymentHistoryViewModel joins every engagement's payments with the client's name and totals an all-time revenue summary")
    func paymentHistoryViewModelAggregatesAcrossEngagements() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = PaymentHistoryViewModel(
            backend: backend,
            professionalID: professional.id,
            clock: { InMemoryStore.referenceDate }
        )
        await viewModel.load()

        #expect(!viewModel.items.isEmpty)
        #expect(viewModel.items.allSatisfy { !$0.clientName.isEmpty })
        let succeededCount = viewModel.items.filter { $0.payment.status == .succeeded }.count
        #expect(viewModel.revenueSummary.count == succeededCount)
        let expectedNet = viewModel.items.compactMap(\.netCents).reduce(0, +)
        #expect(viewModel.revenueSummary.netCents == expectedNet)
    }

    @Test("revenue math with platform fee: a mock-gateway charge nets gross - fee via TodaySummaries.revenueSummary")
    func revenueMathAccountsForPlatformFee() async throws {
        let backend = InMemoryStore.seeded()
        let engagementID = Identifier<Engagement>()
        let charged = try await backend.paymentGateway.charge(engagementID: engagementID, amountCents: 10_000, currency: "USD")

        let summary = TodaySummaries.revenueSummary(from: [charged], now: charged.createdAt, windowDays: 1)

        #expect(summary.grossCents == charged.amountCents)
        #expect(summary.netCents == charged.amountCents - charged.platformFeeCents)
        #expect(summary.netCents == summary.grossCents - charged.platformFeeCents)
    }

    @Test("DoD: a mock charge with an in-window createdAt increases the Today dashboard's revenue")
    func mockChargeIncreasesTodayDashboardRevenue() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let engagement = Engagement(
            id: Identifier(),
            clientID: Identifier(),
            professionalID: professionalID,
            status: .active,
            startedAt: Date(),
            endedAt: nil
        )
        _ = try await backend.engagements.upsert(engagement)

        let before = TodayViewModel(backend: backend, professionalID: professionalID)
        await before.load()
        #expect(before.revenueSummary == .zero)

        let charged = try await backend.paymentGateway.charge(engagementID: engagement.id, amountCents: 20_000, currency: "USD")

        let after = TodayViewModel(backend: backend, professionalID: professionalID)
        await after.load()

        #expect(after.revenueSummary.count == 1)
        #expect(after.revenueSummary.grossCents == charged.amountCents)
        #expect(after.revenueSummary.netCents == charged.amountCents - charged.platformFeeCents)
    }
}
