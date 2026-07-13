/// The current authentication state, as observed live via `AuthGateway.currentAuth`.
public enum AuthState: Sendable, Hashable {
    case signedOut
    case signedIn(AuthenticatedUser)
}
