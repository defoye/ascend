import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("SettingsViewModel role editing")
@MainActor
struct SettingsViewModelTests {
    @Test("addOtherRole turns a client-only Person into a both-role Person")
    func addOtherRoleAddsMissingRoleForClient() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        #expect(morganChen.roles == [.consumer])

        let viewModel = SettingsViewModel(backend: backend, personID: morganChen.id)
        await viewModel.load()
        #expect(viewModel.missingRole == .professional)

        let added = await viewModel.addOtherRole()
        #expect(added)
        #expect(viewModel.roles == [.consumer, .professional])
        #expect(viewModel.missingRole == nil)

        let updatedPerson = try #require(try await backend.people.get(morganChen.id))
        #expect(updatedPerson.roles == [.consumer, .professional])
    }

    @Test("addOtherRole turns a coach-only Person into a both-role Person")
    func addOtherRoleAddsMissingRoleForCoach() async throws {
        let backend = InMemoryBackend()
        let coach = Person(id: Identifier(), displayName: "Solo Coach", roles: [.professional], goals: [])
        _ = try await backend.people.upsert(coach)

        let viewModel = SettingsViewModel(backend: backend, personID: coach.id)
        await viewModel.load()
        #expect(viewModel.missingRole == .consumer)

        let added = await viewModel.addOtherRole()
        #expect(added)

        let updatedPerson = try #require(try await backend.people.get(coach.id))
        #expect(updatedPerson.roles == [.professional, .consumer])
    }

    @Test("a both-role Person has no missing role and addOtherRole is a no-op")
    func bothRolePersonHasNoMissingRole() async throws {
        let backend = InMemoryBackend()
        let person = Person(id: Identifier(), displayName: "Both Roles", roles: [.professional, .consumer], goals: [])
        _ = try await backend.people.upsert(person)

        let viewModel = SettingsViewModel(backend: backend, personID: person.id)
        await viewModel.load()
        #expect(viewModel.missingRole == nil)

        let added = await viewModel.addOtherRole()
        #expect(added == false)
        let unchangedPerson = try #require(try await backend.people.get(person.id))
        #expect(unchangedPerson.roles == [.professional, .consumer])
    }
}
