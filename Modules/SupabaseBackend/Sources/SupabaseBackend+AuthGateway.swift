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

    public func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    public func signUp(email: String, password: String, displayName: String) async throws {
        try await client.auth.signUp(email: email, password: password, data: ["display_name": .string(displayName)])
    }

    public func signOut() async throws {
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
            try await table.upsert(PersonRow(id: personID, displayName: displayName, roles: [.consumer]))
        }

        return AuthenticatedUser(personID: personID, displayName: displayName, email: email)
    }

    private static func displayName(from metadata: [String: AnyJSON]) -> String? {
        guard case .string(let name) = metadata["display_name"] else { return nil }
        return name
    }
}
