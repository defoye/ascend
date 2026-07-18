import DataInterfaces
import Domain
import InMemoryStore
import Observation
import SupabaseBackend

/// The App target's composition root state (see docs/ARCHITECTURE.md): the one
/// place that knows which concrete `Backend` adapter is in use.
///
/// Swapping backends (e.g. `InMemoryBackend` -> a future `SupabaseBackend`) is a
/// one-line change inside `makeBackend()` — everything else in the app depends
/// only on the `Backend` protocol.
@MainActor
@Observable
final class AppContainer {
    let backend: any Backend
    let paymentsMode: PaymentsMode

    /// Resolves the `Person` the consumer (client) experience should render
    /// for a given signed-in user. For every real backend this is just
    /// `user.personID` — the signed-in person *is* the client. The one
    /// exception is the DEBUG `InMemoryStore.seeded()` composition, where the
    /// app signs in as the seeded professional (Jordan Ellis) and the
    /// coherent, hand-picked seeded *client* (an active engagement, an
    /// assigned program, an upcoming session, coach messages, consent
    /// granted — see `InMemoryStore.demoClientPersonID`) is a different
    /// person entirely; substituting it there preserves the role-switch demo.
    /// Set once in `makeBackend()` alongside the backend it corresponds to,
    /// so the two can never drift out of sync.
    let consumerPersonID: @Sendable (AuthenticatedUser) -> Identifier<Person>

    init(
        backend: any Backend,
        paymentsMode: PaymentsMode,
        consumerPersonID: @escaping @Sendable (AuthenticatedUser) -> Identifier<Person> = { $0.personID }
    ) {
        self.backend = backend
        self.paymentsMode = paymentsMode
        self.consumerPersonID = consumerPersonID
    }

    /// Convenience accessor for the backend's authentication gateway.
    var auth: any AuthGateway {
        backend.auth
    }

    /// The single switch for Option B (see docs/BACKEND.md "PaymentsMode:
    /// free-first rollout"): `.free` ships first with no
    /// live payment flows and "Tracked results" instead of "Verified
    /// journeys"; flipping this one line to `.live` restores the charge/pay
    /// UI and the "Verified" badge. Nothing else in the app hardcodes a
    /// mode — every Features view model that branches on it is handed this
    /// value from here.
    static let paymentsMode: PaymentsMode = .free

    /// The default container for this build configuration.
    static func live() -> AppContainer {
        let paymentsMode = Self.paymentsMode
        let (backend, consumerPersonID) = makeBackend(paymentsMode: paymentsMode)
        return AppContainer(backend: backend, paymentsMode: paymentsMode, consumerPersonID: consumerPersonID)
    }

    /// Composes both the backend and its matching `consumerPersonID`
    /// resolver together, in the same `#if DEBUG` branch, so the demo
    /// client-substitution behavior can never end up paired with the wrong
    /// backend (e.g. shipping with a real backend but a hardcoded demo ID).
    private static func makeBackend(
        paymentsMode: PaymentsMode
    ) -> (backend: any Backend, consumerPersonID: @Sendable (AuthenticatedUser) -> Identifier<Person>) {
        #if DEBUG
        // DEBUG always uses InMemoryStore — zero-cost, offline, and what
        // every preview/unit test runs against (see docs/BACKEND.md,
        // docs/TESTING.md). This is unconditional: DEBUG never reads
        // Supabase credentials, so a fresh checkout with no
        // Config/Secrets.xcconfig still builds and runs Debug with zero setup.
        //
        // The seeded DEBUG identity signs in as the professional (Jordan
        // Ellis), so the consumer side has to run as the seeded demo client
        // instead of the signed-in user — see `consumerPersonID`'s doc comment.
        let backend = PaymentsModeBackend(wrapped: InMemoryStore.seeded(), paymentsMode: paymentsMode)
        return (backend, { _ in InMemoryStore.demoClientPersonID })
        #else
        // Release is the only configuration backed by Config/Secrets.xcconfig
        // (see Project.swift's `appSettings`) — SupabaseBackend is the
        // production adapter (docs/BACKEND.md, docs/ARCHITECTURE.md). A
        // missing/invalid SUPABASE_URL or SUPABASE_ANON_KEY fails loudly
        // rather than silently falling back to a demo backend in a shipped
        // build. The signed-in user *is* the client here, so the consumer
        // experience simply runs as their own `personID`.
        do {
            let credentials = try SupabaseConfig.read()
            let supabase = SupabaseBackend(supabaseURL: credentials.url, supabaseKey: credentials.anonKey)
            let backend = PaymentsModeBackend(wrapped: supabase, paymentsMode: paymentsMode)
            return (backend, { $0.personID })
        } catch {
            fatalError("SupabaseBackend configuration failed: \(error). See docs/BACKEND.md.")
        }
        #endif
    }
}
