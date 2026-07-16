import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: InviteRepository {
    public func createInvite(
        forProfessional professionalID: Identifier<Person>,
        suggestedClientName: String?
    ) async throws -> EngagementInvite {
        var code = EngagementInvite.generateCode()
        let existingCodes = Set(invitesByID.values.map(\.code))
        while existingCodes.contains(code) {
            code = EngagementInvite.generateCode()
        }

        let invite = EngagementInvite(
            id: Identifier(),
            code: code,
            professionalID: professionalID,
            suggestedClientName: suggestedClientName,
            createdAt: Date(),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
        invitesByID[invite.id] = invite
        return invite
    }

    public func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite] {
        invitesByID.values
            .filter { $0.professionalID == professionalID && !$0.isClaimed }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func revokeInvite(_ id: Identifier<EngagementInvite>) async throws {
        guard invitesByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }

    public func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement {
        let normalized = EngagementInvite.normalize(code)
        guard let invite = invitesByID.values.first(where: { EngagementInvite.normalize($0.code) == normalized }) else {
            throw InviteError.invalidCode
        }
        guard !invite.isClaimed else { throw InviteError.alreadyClaimed }
        guard invite.professionalID != clientID else { throw InviteError.cannotClaimOwnInvite }

        let engagement = Engagement(
            id: Identifier(),
            clientID: clientID,
            professionalID: invite.professionalID,
            status: .active,
            startedAt: Date(),
            endedAt: nil
        )
        engagementsByID[engagement.id] = engagement

        let now = Date()
        invitesByID[invite.id] = EngagementInvite(
            id: invite.id,
            code: invite.code,
            professionalID: invite.professionalID,
            suggestedClientName: invite.suggestedClientName,
            createdAt: invite.createdAt,
            claimedByPersonID: clientID,
            claimedAt: now,
            engagementID: engagement.id
        )

        if let claimer = peopleByID[clientID], !claimer.roles.contains(.consumer) {
            peopleByID[clientID] = Person(
                id: claimer.id,
                displayName: claimer.displayName,
                roles: claimer.roles.union([.consumer]),
                goals: claimer.goals
            )
        }

        // The registry is generically keyed by `Identifier<Person>`: today only
        // `engagements(forProfessional:)` subscribes (keyed by professional id),
        // but a claim changes both parties' engagement lists, so both keys are
        // yielded — the professional's list for its existing subscribers, and
        // the client's list (harmless no-op today, correct if a client-side
        // stream is ever added on this same registry).
        engagementRegistry.yield(engagementsList(forProfessional: invite.professionalID), for: invite.professionalID)
        engagementRegistry.yield(
            engagementsByID.values.filter { $0.clientID == clientID }.sorted { lhs, rhs in
                (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
            },
            for: clientID
        )

        return engagement
    }
}
