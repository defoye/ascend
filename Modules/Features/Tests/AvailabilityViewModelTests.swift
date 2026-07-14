import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("AvailabilityViewModel against seeded data")
@MainActor
struct AvailabilityViewModelTests {
    @Test("load() fetches the professional's seeded weekly windows")
    func loadFetchesSeededWindows() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = AvailabilityViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()

        #expect(!viewModel.windows.isEmpty)
        #expect(viewModel.windows.allSatisfy { $0.professionalID == professional.id })
        #expect(viewModel.loadErrorMessage == nil)
    }

    @Test("addWindow persists a new window that reload picks up")
    func addWindowPersists() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = AvailabilityViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()
        let countBefore = viewModel.windows.count

        await viewModel.addWindow(weekday: 7, startMinute: 8 * 60, endMinute: 10 * 60)

        #expect(viewModel.windows.count == countBefore + 1)
        let fetched = try await backend.availability.windows(forProfessional: professional.id)
        #expect(fetched.contains { $0.weekday == 7 && $0.startMinute == 8 * 60 && $0.endMinute == 10 * 60 })
    }

    @Test("addWindow rejects an invalid window (end before start) without persisting it")
    func addWindowRejectsInvalidRange() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = AvailabilityViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()
        let countBefore = viewModel.windows.count

        await viewModel.addWindow(weekday: 7, startMinute: 10 * 60, endMinute: 8 * 60)

        #expect(viewModel.windows.count == countBefore)
        #expect(viewModel.saveErrorMessage != nil)
    }

    @Test("deleteWindow removes a window")
    func deleteWindowRemoves() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = AvailabilityViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()
        let target = try #require(viewModel.windows.first)

        await viewModel.deleteWindow(target.id)

        #expect(!viewModel.windows.contains { $0.id == target.id })
        let fetched = try await backend.availability.windows(forProfessional: professional.id)
        #expect(!fetched.contains { $0.id == target.id })
    }
}
