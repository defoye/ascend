/// Errors surfaced by `InMemoryBackend`'s repository implementations.
public enum InMemoryStoreError: Error, Sendable, Equatable {
    /// No record exists for the given identifier.
    case notFound
    /// `AuthGateway.signIn` was called with an email/password pair that doesn't
    /// match a registered user.
    case invalidCredentials
    /// `AuthGateway.signUp` was called with an email that's already registered.
    case emailAlreadyRegistered
}
