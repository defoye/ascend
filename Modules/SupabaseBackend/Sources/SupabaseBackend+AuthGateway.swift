import DataInterfaces
import Domain
import Foundation
import Supabase

/// Supabase Auth-backed `AuthGateway`. `AuthenticatedUser.personID` is the
/// same UUID as Supabase Auth's `auth.users.id` (wrapped as
/// `Identifier<Person>`) — this repository ensures a matching `people` row
/// exists the first time an identity is seen (sign-up, or a sign-in for an
/// identity that predates having one, e.g. created directly in the Supabase
/// dashboard), mirroring `InMemoryBackend.signUp`'s "creates a `Person`"
/// behavior.
extension SupabaseBackend: AuthGateway {
    public var currentAuth: AsyncStream<AuthState> {
        let client = client
        return AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    guard let session else {
                        continuation.yield(.signedOut)
                        continue
                    }
                    if let user = try? await Self.ensurePerson(client: client, queue: queue, session: session) {
                        continuation.yield(.signedIn(user))
                    } else {
                        continuation.yield(.signedOut)
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Maps Supabase Auth's `AuthError.errorCode == .emailNotConfirmed`
    /// (`AuthError.swift`) — the error `signIn` throws when this address
    /// hasn't confirmed the emailed sign-up link yet — to
    /// `AuthGatewayError.emailNotConfirmed`. Every other error rethrows
    /// unchanged.
    public func signIn(email: String, password: String) async throws {
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch let error as AuthError where error.errorCode == .emailNotConfirmed {
            throw AuthGatewayError.emailNotConfirmed
        }
    }

    /// `client.auth.signUp` returns `AuthResponse` (`Types.swift`): `.session`
    /// means Supabase created a session immediately (email confirmation off,
    /// or auto-confirmed), so this maps to `.signedIn`; `.user` means only
    /// the identity was created with no session yet (confirmation pending),
    /// mapping to `.confirmationRequired`.
    public func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws -> SignUpOutcome {
        guard !roles.isEmpty else { throw AuthGatewayError.rolesRequired }
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "display_name": .string(displayName),
                "roles": .array(roles.map { .string($0.rawValue) })
            ]
        )
        switch response {
        case .session: return .signedIn
        case .user: return .confirmationRequired
        }
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Invokes the `delete-account` Edge Function, which runs with
    /// service-role rights server-side and derives the target user from the
    /// caller's JWT — the client never passes an id (see
    /// `Server/supabase/functions/delete-account/index.ts`). Ends the local
    /// session afterward, the same as `signOut`.
    public func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        try await client.auth.signOut()
    }

    // MARK: - Helpers

    private static func ensurePerson(
        client: SupabaseClient,
        queue: OfflineWriteQueue,
        session: Auth.Session
    ) async throws -> AuthenticatedUser {
        let personID = Identifier<Person>(session.user.id)
        let email = session.user.email ?? ""
        let displayName = displayName(from: session.user.userMetadata) ?? email.components(separatedBy: "@").first ?? "Ascend user"

        let table = SupabaseTable<PersonRow>(client: client, queue: queue, table: "people")
        if try await table.fetchOne(id: personID.rawValue) == nil {
            let roles = roles(from: session.user.userMetadata) ?? [.consumer]
            try await table.upsert(PersonRow(id: personID, displayName: displayName, roles: roles))
        }

        return AuthenticatedUser(personID: personID, displayName: displayName, email: email)
    }

    private static func displayName(from metadata: [String: AnyJSON]) -> String? {
        guard case .string(let name) = metadata["display_name"] else { return nil }
        return name
    }

    /// Reads the role(s) chosen at sign-up back out of `user_metadata` (see
    /// `signUp`, which stashes them there — Supabase Auth has no first-class
    /// "roles" field). `nil` when absent (e.g. an identity created directly
    /// in the Supabase dashboard, or a legacy sign-up predating this field),
    /// so the caller can fall back to a sane default.
    private static func roles(from metadata: [String: AnyJSON]) -> Set<PersonRole>? {
        guard case .array(let values) = metadata["roles"] else { return nil }
        let roles = values.compactMap { value -> PersonRole? in
            guard case .string(let raw) = value else { return nil }
            return PersonRole(rawValue: raw)
        }
        return roles.isEmpty ? nil : Set(roles)
    }
}
