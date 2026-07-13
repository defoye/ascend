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

    init(backend: any Backend) {
        self.backend = backend
    }

    /// Convenience accessor for the backend's authentication gateway.
    var auth: any AuthGateway {
        backend.auth
    }

    /// The default container for this build configuration.
    static func live() -> AppContainer {
        AppContainer(backend: makeBackend())
    }

    private static func makeBackend() -> any Backend {
        #if DEBUG
        return InMemoryStore.seeded()
        #else
        fatalError("No production backend configured yet — see docs/BACKEND.md (Prompt 13: SupabaseBackend).")
        #endif
    }
}
