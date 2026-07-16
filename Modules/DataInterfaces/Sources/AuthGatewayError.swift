/// Errors surfaced by `AuthGateway` implementations that are independent of
/// any concrete backend (see docs/BACKEND.md) — validation every adapter
/// (`InMemoryStore`, `SupabaseBackend`) enforces identically, rather than
/// leaving it to each backend to invent its own case.
public enum AuthGatewayError: Error, Sendable, Equatable {
    /// `signUp` was called with an empty `roles` set. Every person must hold
    /// at least one `PersonRole` at sign-up (see docs/PRODUCT.md "Roles").
    case rolesRequired
    /// `signIn` was rejected because this address hasn't confirmed the
    /// emailed link from sign-up yet (see `SignUpOutcome.confirmationRequired`).
    case emailNotConfirmed
}
