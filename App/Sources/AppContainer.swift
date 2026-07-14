import DataInterfaces
import InMemoryStore
import Observation

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
        return PaymentsModeBackend(wrapped: InMemoryStore.seeded(), paymentsMode: paymentsMode)
        #else
        fatalError("No production backend configured yet — see docs/BACKEND.md (Prompt 13: SupabaseBackend).")
        #endif
    }
}
