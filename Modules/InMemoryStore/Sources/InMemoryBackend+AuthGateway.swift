import DataInterfaces
import Domain
import Foundation

extension InMemoryBackend: AuthGateway {
    nonisolated public var currentAuth: AsyncStream<AuthState> {
        let token = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeAuthSubscription(token: token) }
            }
            Task {
                await self.registerAuthSubscription(token: token, continuation: continuation)
            }
        }
    }

    public func signIn(email: String, password: String) async throws {
        guard let entry = registeredUsers[email], entry.password == password else {
            throw InMemoryStoreError.invalidCredentials
        }
        currentAuthState = .signedIn(entry.user)
        authRegistry.yield(currentAuthState, for: SingletonKey())
    }

    public func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws {
        guard !roles.isEmpty else { throw AuthGatewayError.rolesRequired }
        guard registeredUsers[email] == nil else { throw InMemoryStoreError.emailAlreadyRegistered }
        let person = Person(id: Identifier(), displayName: displayName, roles: roles, goals: [])
        peopleByID[person.id] = person
        let user = AuthenticatedUser(personID: person.id, displayName: displayName, email: email)
        registeredUsers[email] = (password, user)
        currentAuthState = .signedIn(user)
        authRegistry.yield(currentAuthState, for: SingletonKey())
    }

    public func signOut() async throws {
        currentAuthState = .signedOut
        authRegistry.yield(currentAuthState, for: SingletonKey())
    }

    public func deleteAccount() async throws {
        if case .signedIn(let user) = currentAuthState {
            registeredUsers = registeredUsers.filter { $0.value.user.personID != user.personID }
        }
        currentAuthState = .signedOut
        authRegistry.yield(currentAuthState, for: SingletonKey())
    }

    // MARK: - Helpers

    func registerAuthSubscription(token: UUID, continuation: AsyncStream<AuthState>.Continuation) {
        authRegistry.register(key: SingletonKey(), token: token, continuation: continuation, currentValue: currentAuthState)
    }

    func removeAuthSubscription(token: UUID) {
        authRegistry.remove(key: SingletonKey(), token: token)
    }
}
