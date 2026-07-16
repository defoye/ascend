import DataInterfaces
import Domain
import Foundation

// MARK: - Invite fixtures
//
// Split into its own file (rather than kept in `PreviewBackend.swift`) purely
// to stay under SwiftLint's `file_length` — SwiftLint measures each file
// independently, mirroring the other `PreviewBackend+*.swift` splits.
extension PreviewBackend {
    static func makePendingInvites(professionalID: Identifier<Person>, now: Date) -> [EngagementInvite] {
        [
            EngagementInvite(
                id: Identifier(),
                code: "K7M2PQXR",
                professionalID: professionalID,
                suggestedClientName: "Taylor Reyes",
                createdAt: now.addingTimeInterval(-2 * 86_400),
                claimedByPersonID: nil,
                claimedAt: nil,
                engagementID: nil
            )
        ]
    }
}

struct PreviewInviteRepository: InviteRepository {
    let pendingInvitesList: [EngagementInvite]

    func createInvite(forProfessional professionalID: Identifier<Person>, suggestedClientName: String?) async throws -> EngagementInvite {
        EngagementInvite(
            id: Identifier(),
            code: EngagementInvite.generateCode(),
            professionalID: professionalID,
            suggestedClientName: suggestedClientName,
            createdAt: Date(),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
    }

    func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite] {
        pendingInvitesList.filter { $0.professionalID == professionalID }
    }

    func revokeInvite(_ id: Identifier<EngagementInvite>) async throws {}

    func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement {
        Engagement(id: Identifier(), clientID: clientID, professionalID: Identifier(), status: .active, startedAt: Date(), endedAt: nil)
    }
}
