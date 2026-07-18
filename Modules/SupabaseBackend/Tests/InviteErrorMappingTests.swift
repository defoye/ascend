import DataInterfaces
import Domain
import Foundation
import Supabase
import Testing
@testable import SupabaseBackend

/// Locks the adapter side of the `claim_invite` error contract
/// (`SupabaseBackend+InviteRepository.mapClaimInviteError`). The RPC's SQL
/// `RAISE EXCEPTION` messages — `"invalid_code"`, `"already_claimed"`,
/// `"cannot_claim_own_invite"` (see migration `20260716120000_engagement_invites.sql`)
/// — reach the app as a `PostgrestError.message`, and the adapter translates
/// each into the matching `InviteError` case that `ClaimInviteViewModel`
/// renders. That translation is the ONE piece of invite logic exercised only
/// by the live-skipping `SupabaseLiveRoundTripTests`, so with no credentials
/// in CI it was previously untested: a typo'd case string here would fail
/// silently (a real DB rejection surfacing as a raw Postgrest error the UI
/// can't map) with nothing red. These tests pin the mapping without a live
/// project.
///
/// Scope note: this proves only the Swift half of the contract. That the SQL
/// actually raises these exact strings still needs the live round-trip — this
/// test cannot see the migration.
@Suite("Claim-invite error mapping")
struct InviteErrorMappingTests {
    @Test("invalid_code maps to InviteError.invalidCode")
    func mapsInvalidCode() {
        let mapped = SupabaseBackend.mapClaimInviteError(PostgrestError(message: "invalid_code"))
        #expect(mapped as? InviteError == .invalidCode)
    }

    @Test("already_claimed maps to InviteError.alreadyClaimed")
    func mapsAlreadyClaimed() {
        let mapped = SupabaseBackend.mapClaimInviteError(PostgrestError(message: "already_claimed"))
        #expect(mapped as? InviteError == .alreadyClaimed)
    }

    @Test("cannot_claim_own_invite maps to InviteError.cannotClaimOwnInvite")
    func mapsCannotClaimOwnInvite() {
        let mapped = SupabaseBackend.mapClaimInviteError(PostgrestError(message: "cannot_claim_own_invite"))
        #expect(mapped as? InviteError == .cannotClaimOwnInvite)
    }

    /// The `default:` branch: an unexpected DB failure must propagate as-is,
    /// never be laundered into one of the three known `InviteError` cases
    /// (which would show the user a wrong, reassuring "that code is invalid"
    /// for what is actually an unrelated server error).
    @Test("an unrecognized Postgrest message is returned unchanged, not coerced into an InviteError")
    func passesThroughUnknownPostgrestMessage() {
        let original = PostgrestError(message: "some_unexpected_constraint_violation")
        let mapped = SupabaseBackend.mapClaimInviteError(original)
        #expect(mapped as? InviteError == nil)
        #expect((mapped as? PostgrestError)?.message == "some_unexpected_constraint_violation")
    }

    /// The `guard` branch: a non-Postgrest failure (transport/decoding) must
    /// pass straight through so retry/offline handling upstream still sees the
    /// real error type.
    @Test("a non-Postgrest error (e.g. transport failure) is returned unchanged")
    func passesThroughNonPostgrestError() {
        let transport = URLError(.notConnectedToInternet)
        let mapped = SupabaseBackend.mapClaimInviteError(transport)
        #expect(mapped as? InviteError == nil)
        #expect((mapped as? URLError)?.code == .notConnectedToInternet)
    }
}
