import Domain

/// Errors shared across every `InviteRepository` conformer (see
/// `claimInvite`'s doc comment for exactly when each is thrown).
public enum InviteError: Error, Equatable, Sendable {
    /// No unclaimed invite matches the (normalized) code.
    case invalidCode
    /// The matched invite has already been claimed by someone else.
    case alreadyClaimed
    /// The claiming person is the same professional who created the invite.
    case cannotClaimOwnInvite
}

/// CRUD access to `EngagementInvite` records, plus the claim flow that turns
/// an invite into an `Engagement` (see docs/DATA_MODEL.md).
///
/// This is the entire replacement for coach-created client accounts: a coach
/// can never create another person's `Person` row (production RLS requires
/// `people.id == auth.uid()`), so onboarding instead runs through a
/// coach-issued code that the client claims under their own account.
public protocol InviteRepository: Sendable {
    /// Creates a new, unclaimed invite for `professionalID`, generating a
    /// fresh code (see `EngagementInvite.generateCode()`).
    func createInvite(forProfessional professionalID: Identifier<Person>, suggestedClientName: String?) async throws -> EngagementInvite

    /// The professional's invites that haven't been claimed yet.
    func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite]

    /// Revokes (deletes) an invite, e.g. one the coach no longer wants live.
    func revokeInvite(_ id: Identifier<EngagementInvite>) async throws

    /// Claims an invite by its (case-insensitive, whitespace-trimmed) code on
    /// behalf of `clientID`, creating and returning the resulting `Engagement`.
    ///
    /// Every conformer must honor the same semantics: look up an unclaimed
    /// invite by normalized code, throwing `InviteError.invalidCode` if none
    /// exists, `InviteError.alreadyClaimed` if it's already claimed, and
    /// `InviteError.cannotClaimOwnInvite` if `clientID == professionalID` on
    /// the invite. On success, creates a new `.active` `Engagement` linking
    /// `clientID` to the invite's `professionalID`, marks the invite claimed,
    /// and — if the claiming person exists and lacks `.consumer` in `roles` —
    /// adds it, since role-gated UI depends on `roles` being truthful.
    func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement
}
