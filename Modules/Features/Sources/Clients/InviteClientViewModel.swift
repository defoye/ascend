import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the "Invite client" flow: create an `EngagementInvite` code
/// to share with a prospective client, and manage the coach's still-pending
/// invites (see `InviteRepository`).
///
/// Replaces the old "Add client" flow, which created a `Person` row with a
/// coach-generated id — something production Supabase RLS rejects outright
/// (`people` inserts require `id == auth.uid()`). Invite-based onboarding is
/// the only path that works: the client's own signed-in account is what
/// claims the invite and creates the engagement.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class InviteClientViewModel {
    public var suggestedClientName = ""
    public private(set) var pendingInvites: [EngagementInvite] = []
    public private(set) var createdInvite: EngagementInvite?
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(backend: any Backend, professionalID: Identifier<Person>) {
        self.backend = backend
        self.professionalID = professionalID
    }

    /// Loads the coach's currently pending (unclaimed) invites.
    public func load() async {
        do {
            pendingInvites = try await backend.invites.pendingInvites(forProfessional: professionalID)
            errorMessage = nil
        } catch {
            pendingInvites = []
            errorMessage = "Couldn't load your pending invites. Try again."
        }
    }

    /// Creates a new invite from the current `suggestedClientName`, surfaces
    /// it as `createdInvite` for the share sheet, and refreshes the pending
    /// list.
    public func createInvite() async {
        isSaving = true
        defer { isSaving = false }

        let trimmedName = suggestedClientName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let invite = try await backend.invites.createInvite(
                forProfessional: professionalID,
                suggestedClientName: trimmedName.isEmpty ? nil : trimmedName
            )
            createdInvite = invite
            suggestedClientName = ""
            errorMessage = nil
            await load()
        } catch {
            errorMessage = "Couldn't create an invite. Try again."
        }
    }

    /// Revokes a pending invite and refreshes the list.
    public func revoke(_ invite: EngagementInvite) async {
        do {
            try await backend.invites.revokeInvite(invite.id)
            if createdInvite?.id == invite.id {
                createdInvite = nil
            }
            await load()
        } catch {
            errorMessage = "Couldn't revoke this invite. Try again."
        }
    }
}
