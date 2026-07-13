/// Authentication, independent of any concrete provider (Supabase Auth, etc. — see
/// docs/BACKEND.md).
public protocol AuthGateway: Sendable {
    /// Live authentication state: emits the current state immediately upon
    /// subscription, then again on every sign-in/sign-out.
    var currentAuth: AsyncStream<AuthState> { get }

    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String, displayName: String) async throws
    func signOut() async throws
}
