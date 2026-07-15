import DataInterfaces
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

    init(backend: any Backend, paymentsMode: PaymentsMode) {
        self.backend = backend
        self.paymentsMode = paymentsMode
    }

    /// Convenience accessor for the backend's authentication gateway.
    var auth: any AuthGateway {
        backend.auth
    }

    /// The single switch for Option B (see docs/BUILD_STATUS.md "Rollout
    /// strategy — free first, monetize later"): `.free` ships first with no
    /// live payment flows and "Tracked results" instead of "Verified
    /// journeys"; flipping this one line to `.live` restores the charge/pay
    /// UI and the "Verified" badge. Nothing else in the app hardcodes a
    /// mode — every Features view model that branches on it is handed this
    /// value from here.
    static let paymentsMode: PaymentsMode = .free

    /// The default container for this build configuration.
    static func live() -> AppContainer {
        let paymentsMode = Self.paymentsMode
        return AppContainer(backend: makeBackend(paymentsMode: paymentsMode), paymentsMode: paymentsMode)
    }

    private static func makeBackend(paymentsMode: PaymentsMode) -> any Backend {
        #if DEBUG
        // DEBUG always uses InMemoryStore — zero-cost, offline, and what
        // every preview/unit test runs against (see docs/BACKEND.md,
        // docs/TESTING.md). This is unconditional: DEBUG never reads
        // Supabase credentials, so a fresh checkout with no
        // Config/Secrets.xcconfig still builds and runs Debug with zero setup.
        return PaymentsModeBackend(wrapped: InMemoryStore.seeded(), paymentsMode: paymentsMode)
        #else
        // Release is the only configuration backed by Config/Secrets.xcconfig
        // (see Project.swift's `appSettings`) — SupabaseBackend is the
        // production adapter (docs/BACKEND.md, docs/ARCHITECTURE.md). A
        // missing/invalid SUPABASE_URL or SUPABASE_ANON_KEY fails loudly
        // rather than silently falling back to a demo backend in a shipped
        // build.
        do {
            let credentials = try SupabaseConfig.read()
            let supabase = SupabaseBackend(supabaseURL: credentials.url, supabaseKey: credentials.anonKey)
            return PaymentsModeBackend(wrapped: supabase, paymentsMode: paymentsMode)
        } catch {
            fatalError("SupabaseBackend configuration failed: \(error). See docs/BACKEND.md.")
        }
        #endif
    }
}
