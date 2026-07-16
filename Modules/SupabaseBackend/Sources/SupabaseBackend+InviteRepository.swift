import DataInterfaces
import Domain
import Foundation
import Supabase

extension SupabaseBackend: InviteRepository {
    public func createInvite(
        forProfessional professionalID: Identifier<Person>,
        suggestedClientName: String?
    ) async throws -> EngagementInvite {
        let invite = EngagementInvite(
            id: Identifier(),
            code: EngagementInvite.generateCode(),
            professionalID: professionalID,
            suggestedClientName: suggestedClientName,
            createdAt: Date(),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
        try await engagementInvitesTable.upsert(EngagementInviteRow(domain: invite))
        return invite
    }

    public func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite] {
        let rows = try await engagementInvitesTable.fetchAll {
            $0.eq("professional_id", value: professionalID.rawValue).is("claimed_by", value: nil)
        }
        return rows.map(\.toDomain).sorted { $0.createdAt > $1.createdAt }
    }

    public func revokeInvite(_ id: Identifier<EngagementInvite>) async throws {
        try await engagementInvitesTable.delete(id: id.rawValue)
    }

    /// Claims an invite server-side via the `claim_invite` Postgres RPC (SQL
    /// lands in the LH-3 migration — this adapter is written against the
    /// contract that migration must implement). `clientID` is passed for
    /// signature symmetry with `InviteRepository` but is otherwise unused:
    /// the RPC runs as the authenticated caller, so `auth.uid()` — not any
    /// client-supplied id — is authoritative for who is claiming.
    ///
    /// The RPC is expected to `RAISE EXCEPTION` with a message of exactly
    /// `"invalid_code"`, `"already_claimed"`, or `"cannot_claim_own_invite"`
    /// for the matching `InviteError` case; any other failure (including a
    /// non-`PostgrestError`, e.g. a transport failure) is rethrown as-is.
    public func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement {
        let normalizedCode = EngagementInvite.normalize(code)
        do {
            let response = try await client.rpc("claim_invite", params: ["invite_code": normalizedCode]).execute()
            let row = try Self.jsonDecoder.decode(EngagementRow.self, from: response.data)
            return row.toDomain
        } catch {
            throw Self.mapClaimInviteError(error)
        }
    }

    private static func mapClaimInviteError(_ error: Error) -> Error {
        guard let postgrestError = error as? PostgrestError else { return error }
        switch postgrestError.message {
        case "invalid_code": return InviteError.invalidCode
        case "already_claimed": return InviteError.alreadyClaimed
        case "cannot_claim_own_invite": return InviteError.cannotClaimOwnInvite
        default: return error
        }
    }

    var engagementInvitesTable: SupabaseTable<EngagementInviteRow> {
        SupabaseTable(client: client, queue: queue, table: "engagement_invites")
    }
}
