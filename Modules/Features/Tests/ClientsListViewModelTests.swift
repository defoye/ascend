import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ClientsListViewModel against seeded data")
@MainActor
struct ClientsListViewModelTests {
    @Test("load() joins every engagement with its client's name/goal and computed last activity")
    func loadsFullRoster() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = ClientsListViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate })
        await viewModel.load()

        #expect(viewModel.roster.count == 8)
        #expect(viewModel.loadErrorMessage == nil)
        // Active-status engagements should sort before pending/paused/completed/ended.
        let firstNonActiveIndex = viewModel.roster.firstIndex { $0.status != .active }
        if let firstNonActiveIndex {
            #expect(viewModel.roster[..<firstNonActiveIndex].allSatisfy { $0.status == .active })
        }
    }

    @Test("statusFilter and searchText narrow filteredRoster independently of the underlying roster")
    func filteredRosterAppliesStatusAndSearch() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = ClientsListViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate })
        await viewModel.load()

        viewModel.statusFilter = .pending
        #expect(viewModel.filteredRoster.allSatisfy { $0.status == .pending })

        viewModel.statusFilter = nil
        viewModel.searchText = "morgan"
        #expect(viewModel.filteredRoster.map(\.clientName) == ["Morgan Chen"])
    }
}
