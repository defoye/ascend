import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

@Suite("InMemoryBackend as InviteRepository")
struct InviteRepositoryTests {
    @Test("createInvite is listed by pendingInvites for that professional")
    func createInviteAppearsInPendingInvites() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()

        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: "Riley Jordan")

        #expect(invite.professionalID == professionalID)
        #expect(invite.suggestedClientName == "Riley Jordan")
        #expect(!invite.isClaimed)
        #expect(invite.code.count == 8)

        let pending = try await backend.invites.pendingInvites(forProfessional: professionalID)
        #expect(pending.map(\.id) == [invite.id])
    }

    @Test("claiming an invite creates an active Engagement with the right parties, marks the invite claimed, and removes it from pending")
    func claimCreatesEngagementAndMarksInviteClaimed() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let clientID = Identifier<Person>()

        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)

        let engagement = try await backend.invites.claimInvite(code: invite.code, clientID: clientID)

        #expect(engagement.clientID == clientID)
        #expect(engagement.professionalID == professionalID)
        #expect(engagement.status == .active)
        #expect(engagement.startedAt != nil)
        #expect(engagement.endedAt == nil)

        let fetchedEngagement = try await backend.engagements.get(engagement.id)
        #expect(fetchedEngagement == engagement)

        let pendingAfterClaim = try await backend.invites.pendingInvites(forProfessional: professionalID)
        #expect(pendingAfterClaim.isEmpty)
    }

    @Test("claiming an invite adds the .consumer role to the claiming person when they lack it")
    func claimAddsConsumerRoleWhenMissing() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let client = Person(id: Identifier(), displayName: "New Client", roles: [], goals: [])
        _ = try await backend.people.upsert(client)

        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)
        _ = try await backend.invites.claimInvite(code: invite.code, clientID: client.id)

        let updated = try await backend.people.get(client.id)
        #expect(updated?.roles.contains(.consumer) == true)
    }

    @Test("claiming an invite twice fails with alreadyClaimed the second time")
    func claimingTwiceThrowsAlreadyClaimed() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)

        _ = try await backend.invites.claimInvite(code: invite.code, clientID: Identifier())

        await #expect(throws: InviteError.alreadyClaimed) {
            try await backend.invites.claimInvite(code: invite.code, clientID: Identifier())
        }
    }

    @Test("claiming an unknown code throws invalidCode")
    func claimingUnknownCodeThrowsInvalidCode() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InviteError.invalidCode) {
            try await backend.invites.claimInvite(code: "NOPE0000", clientID: Identifier())
        }
    }

    @Test("claiming your own invite throws cannotClaimOwnInvite")
    func claimingOwnInviteThrowsCannotClaimOwnInvite() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)

        await #expect(throws: InviteError.cannotClaimOwnInvite) {
            try await backend.invites.claimInvite(code: invite.code, clientID: professionalID)
        }
    }

    @Test("claim matching is case-insensitive and whitespace-trimmed")
    func claimMatchingIsCaseInsensitiveAndTrimmed() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)

        let engagement = try await backend.invites.claimInvite(code: "  \(invite.code.lowercased())  ", clientID: Identifier())
        #expect(engagement.professionalID == professionalID)
    }

    @Test("revokeInvite removes it from pending invites")
    func revokeRemovesFromPending() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let invite = try await backend.invites.createInvite(forProfessional: professionalID, suggestedClientName: nil)

        try await backend.invites.revokeInvite(invite.id)

        let pending = try await backend.invites.pendingInvites(forProfessional: professionalID)
        #expect(pending.isEmpty)
    }

    @Test("revoking an unknown invite throws")
    func revokeUnknownThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.invites.revokeInvite(Identifier())
        }
    }
}
