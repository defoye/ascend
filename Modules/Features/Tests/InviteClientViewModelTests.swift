import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("InviteClientViewModel against seeded data")
@MainActor
struct InviteClientViewModelTests {
    @Test("createInvite creates a pending invite and surfaces it as createdInvite")
    func createInviteSurfacesCreatedInviteAndAppearsInPending() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = InviteClientViewModel(backend: backend, professionalID: professional.id)
        viewModel.suggestedClientName = "Riley Jordan"

        await viewModel.createInvite()

        let createdInvite = try #require(viewModel.createdInvite)
        #expect(createdInvite.professionalID == professional.id)
        #expect(createdInvite.suggestedClientName == "Riley Jordan")
        #expect(viewModel.suggestedClientName.isEmpty)
        #expect(viewModel.pendingInvites.map(\.id).contains(createdInvite.id))
        #expect(viewModel.errorMessage == nil)
    }

    @Test("load() populates pendingInvites from the backend")
    func loadPopulatesPendingInvites() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let invite = try await backend.invites.createInvite(forProfessional: professional.id, suggestedClientName: "Casey")

        let viewModel = InviteClientViewModel(backend: backend, professionalID: professional.id)
        await viewModel.load()

        #expect(viewModel.pendingInvites.map(\.id).contains(invite.id))
    }

    @Test("revoke removes an invite from pendingInvites and from the backend")
    func revokeRemovesInvite() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = InviteClientViewModel(backend: backend, professionalID: professional.id)
        await viewModel.createInvite()
        let invite = try #require(viewModel.createdInvite)

        await viewModel.revoke(invite)

        #expect(!viewModel.pendingInvites.map(\.id).contains(invite.id))
        let remaining = try await backend.invites.pendingInvites(forProfessional: professional.id)
        #expect(!remaining.map(\.id).contains(invite.id))
    }
}
