import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ProgramsListViewModel against seeded data")
@MainActor
struct ProgramsListViewModelTests {
    @Test("load() lists the professional's authored programs, alphabetized by title")
    func loadsAuthoredPrograms() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = ProgramsListViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()

        #expect(viewModel.loadErrorMessage == nil)
        #expect(viewModel.programs.map(\.title) == ["Fat Loss Kickstart", "Strength Foundations"])
    }
}
