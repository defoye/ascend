import Domain

/// The result of `AuthGateway.signUp`. Supabase Auth's "Confirm email"
/// project setting determines which case a given sign-up produces —
/// confirmation off (or already auto-confirmed) yields `.signedIn`
/// immediately; confirmation on yields `.confirmationRequired` and no
/// session exists until the user follows the emailed link and signs in.
public enum SignUpOutcome: Sendable, Equatable {
    case signedIn
    /// The identity was created but no session exists yet — the user must
    /// confirm via the emailed link before they can sign in.
    case confirmationRequired
}

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
    /// via `PersonRepository.upsert`. Returns `.confirmationRequired`
    /// instead of signing in immediately when the backend requires the
    /// user to confirm their email first (see `SignUpOutcome`).
    func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws -> SignUpOutcome
    func signOut() async throws
    /// Permanently destroys the signed-in **auth identity** and ends the
    /// session — distinct from `AccountDeletionEffect`, which anonymizes
    /// (never deletes) the corresponding `Person` row. Call this only after
    /// `AccountDeletionEffect.deleteAccount` reports `personAnonymized`, so
    /// the credential is removed last, once the data sweep has succeeded.
    func deleteAccount() async throws
}
