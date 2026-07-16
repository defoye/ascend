import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ClaimInviteViewModel against seeded data")
@MainActor
struct ClaimInviteViewModelTests {
    @Test("claiming a valid code succeeds and surfaces the resulting Engagement")
    func claimingValidCodeSucceeds() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let invite = try await backend.invites.createInvite(forProfessional: professional.id, suggestedClientName: nil)
        let client = Person(id: Identifier(), displayName: "New Client", roles: [], goals: [])
        _ = try await backend.people.upsert(client)

        let viewModel = ClaimInviteViewModel(backend: backend, clientID: client.id)
        viewModel.code = "  \(invite.code.lowercased())  "

        let succeeded = await viewModel.claim()

        #expect(succeeded)
        #expect(viewModel.claimedEngagement?.clientID == client.id)
        #expect(viewModel.claimedEngagement?.professionalID == professional.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("an invalid code maps to the invalid-code message")
    func invalidCodeMapsToMessage() async throws {
        let backend = InMemoryStore.seeded()
        let viewModel = ClaimInviteViewModel(backend: backend, clientID: Identifier())
        viewModel.code = "NOPE0000"

        let succeeded = await viewModel.claim()

        #expect(!succeeded)
        #expect(viewModel.claimedEngagement == nil)
        #expect(viewModel.errorMessage == "That code didn't work. Double-check it with your coach.")
    }

    @Test("an already-claimed code maps to the already-claimed message")
    func alreadyClaimedMapsToMessage() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let invite = try await backend.invites.createInvite(forProfessional: professional.id, suggestedClientName: nil)
        _ = try await backend.invites.claimInvite(code: invite.code, clientID: Identifier())

        let viewModel = ClaimInviteViewModel(backend: backend, clientID: Identifier())
        viewModel.code = invite.code

        let succeeded = await viewModel.claim()

        #expect(!succeeded)
        #expect(viewModel.errorMessage == "That code was already used.")
    }

    @Test("claiming your own invite maps to a generic message")
    func cannotClaimOwnInviteMapsToGenericMessage() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let invite = try await backend.invites.createInvite(forProfessional: professional.id, suggestedClientName: nil)

        let viewModel = ClaimInviteViewModel(backend: backend, clientID: professional.id)
        viewModel.code = invite.code

        let succeeded = await viewModel.claim()

        #expect(!succeeded)
        #expect(viewModel.errorMessage == "That code didn't work. Try again.")
    }

    @Test("isValid requires non-blank code")
    func isValidRequiresNonBlankCode() {
        let viewModel = ClaimInviteViewModel(backend: InMemoryStore.seeded(), clientID: Identifier())
        #expect(!viewModel.isValid)
        viewModel.code = "   "
        #expect(!viewModel.isValid)
        viewModel.code = "ABCD1234"
        #expect(viewModel.isValid)
    }
}
