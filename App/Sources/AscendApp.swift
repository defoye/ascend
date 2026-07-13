import DataInterfaces
import DesignSystem
import Domain
import Features
import InMemoryStore
import SwiftUI

/// Ascend's app entry point.
///
/// The App target is the sole composition root (see docs/ARCHITECTURE.md):
/// this is the one place that knows about a concrete backend adapter.
/// In DEBUG builds today that's `InMemoryStore`; a future Supabase adapter
/// slots in here without touching Domain, DataInterfaces, Features, or
/// DesignSystem.
@main
struct AscendApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
        }
    }
}

/// Root view: switches on live authentication state from `container.backend.auth`.
/// The seeded `InMemoryStore` backend (see `AppContainer`) starts **signed in**
/// as the demo professional (Jordan Ellis), so the coach dashboard renders
/// immediately at launch. A real sign-in flow for `.signedOut` is a later prompt.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var authState: AuthState = .signedOut

    var body: some View {
        Group {
            switch authState {
            case let .signedIn(user):
                CoachRootView(backend: container.backend, professionalID: user.personID, clock: Self.demoClock)
            case .signedOut:
                SignedOutView()
            }
        }
        .task {
            for await state in container.auth.currentAuth {
                authState = state
            }
        }
    }

    /// Seeded `MockData` fixture dates are anchored at a fixed reference
    /// instant (~2023-11-14), not the real clock — see
    /// `InMemoryStore.referenceDate` — so its "upcoming" sessions would
    /// otherwise always read as in the past. Only the App composition root
    /// knows this is a demo backend (`Features` never imports
    /// `InMemoryStore` — see docs/ARCHITECTURE.md), so it's the one place
    /// that can bridge the seeded fixture's clock into the dashboard.
    private static var demoClock: @Sendable () -> Date {
        #if DEBUG
        { InMemoryStore.referenceDate }
        #else
        { Date() }
        #endif
    }
}

/// Minimal placeholder shown while signed out. A real sign-in screen is a
/// later prompt; this just keeps the composition root's auth-state switch
/// exhaustive.
private struct SignedOutView: View {
    var body: some View {
        VStack(spacing: Spacing.space4) {
            Text("Signed out")
                .ascendType(.title2)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text("Sign-in is coming in a later prompt.")
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
        .padding(Spacing.space6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Ascend.background)
    }
}

#Preview {
    RootView()
        .environment(AppContainer.live())
}
