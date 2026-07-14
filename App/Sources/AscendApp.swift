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

/// Which side of the app is currently active. Ascend's product model is one
/// `Person` with role modes `consumer`/`professional`/`both` (see
/// docs/PRODUCT.md) — a real implementation would derive this from the
/// signed-in person's `roles` and a persisted preference, not a
/// composition-root toggle. Until sign-in supports both roles on one
/// account, this is the App's own demo mechanism for reaching the consumer
/// experience against the same seeded backend as the coach side, switchable
/// via each root's "Switch role" affordance (see docs/design/DESIGN_SPEC.md
/// §4 "Role switch").
enum DemoRole {
    case professional
    case consumer
}

/// Root view: switches on live authentication state from `container.backend.auth`.
/// The seeded `InMemoryStore` backend (see `AppContainer`) starts **signed in**
/// as the demo professional (Jordan Ellis), so the coach dashboard renders
/// immediately at launch. A real sign-in flow for `.signedOut` is a later prompt.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var authState: AuthState = .signedOut
    @State private var activeRole: DemoRole = .professional

    var body: some View {
        Group {
            switch authState {
            case let .signedIn(user):
                roleRoot(for: user)
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

    @ViewBuilder
    private func roleRoot(for user: AuthenticatedUser) -> some View {
        switch activeRole {
        case .professional:
            CoachRootView(
                backend: container.backend,
                professionalID: user.personID,
                clock: Self.demoClock,
                paymentsMode: container.paymentsMode,
                onSwitchRole: { activeRole = .consumer }
            )
        case .consumer:
            ConsumerRootView(
                backend: container.backend,
                clientID: Self.demoClientPersonID,
                clock: Self.demoClock,
                paymentsMode: container.paymentsMode,
                onSwitchRole: { activeRole = .professional }
            )
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

    /// The seeded consumer the demo client experience runs against (see
    /// `InMemoryStore.demoClientPersonID`) — a coherent, hand-picked seeded
    /// client (an active engagement, an assigned program, an upcoming
    /// session, coach messages, and consent granted), not an arbitrary or
    /// empty one. Only meaningful against the seeded `InMemoryStore`
    /// backend; a future production backend would resolve the signed-in
    /// person's own client identity instead.
    private static var demoClientPersonID: Identifier<Person> {
        #if DEBUG
        InMemoryStore.demoClientPersonID
        #else
        Identifier<Person>()
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
