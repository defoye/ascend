import Domain

/// Authentication, independent of any concrete provider (Supabase Auth, etc. — see
/// docs/BACKEND.md).
public protocol AuthGateway: Sendable {
    /// Live authentication state: emits the current state immediately upon
    /// subscription, then again on every sign-in/sign-out.
    var currentAuth: AsyncStream<AuthState> { get }

    func signIn(email: String, password: String) async throws
    /// Creates a new `Person` and signs them in. `roles` is the role(s) they
    /// chose at sign-up (see docs/PRODUCT.md "Roles") — "Coach" ->
    /// `[.professional]`, "Training with a coach" -> `[.consumer]`, "Both"
    /// -> both. Must be non-empty; implementations throw
    /// `AuthGatewayError.rolesRequired` otherwise. Roles are editable later
    /// via `PersonRepository.upsert`.
    func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws
    func signOut() async throws
    /// Permanently destroys the signed-in **auth identity** and ends the
    /// session — distinct from `AccountDeletionEffect`, which anonymizes
    /// (never deletes) the corresponding `Person` row. Call this only after
    /// `AccountDeletionEffect.deleteAccount` reports `personAnonymized`, so
    /// the credential is removed last, once the data sweep has succeeded.
    func deleteAccount() async throws
}
