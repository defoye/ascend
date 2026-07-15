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
/// immediately at launch. Signing out (Settings ▸ Sign out) lands on
/// `Features`' `AuthView` — a real sign-in/sign-up flow with a role picker
/// (see `AuthViewModel`) that creates a `Person` with the chosen `roles` on
/// sign-up; `currentAuth` transitions back to `.signedIn` automatically on
/// success.
///
/// The active role is persisted and roles-gated (see `RolePresenceStore`,
/// `RoleGating`): a person who holds only one `PersonRole` is forced onto it
/// with no switcher; a person who holds both sees the "Switch role"
/// affordance (docs/design/DESIGN_SPEC.md §4), and a quiet dot lights up
/// when the other role has new inbound activity since it was last visited
/// (`RoleActivitySummary`, in `Features`).
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var authState: AuthState = .signedOut
    @State private var rolePresence = RolePresenceStore()
    @State private var activeRole: PersonRole = .professional
    @State private var availableRoles: Set<PersonRole> = [.professional]
    @State private var otherRoleHasUpdates = false
    #if DEBUG
    @State private var demoModeStore = DemoModeStore()
    @State private var demoHarnessState = DemoHarnessState()
    #endif

    var body: some View {
        Group {
            switch authState {
            case let .signedIn(user):
                #if DEBUG
                if demoModeStore.isEnabled {
                    demoRoot
                } else {
                    roleRoot(for: user)
                }
                #else
                roleRoot(for: user)
                #endif
            case .signedOut:
                AuthView(viewModel: AuthViewModel(auth: container.auth))
            }
        }
        .task {
            for await state in container.auth.currentAuth {
                authState = state
            }
        }
        .task(id: signedInPersonID) {
            guard let personID = signedInPersonID else { return }
            await resolveRoleGating(personID: personID)
        }
        .onChange(of: activeRole) { _, newValue in
            rolePresence.markVisited(newValue, at: Date())
            guard let personID = signedInPersonID else { return }
            Task { await refreshOtherRoleUpdates(signedInPersonID: personID) }
        }
        #if DEBUG
        .task(id: demoModeStore.isEnabled ? demoModeStore.scenario.rawValue : "off") {
            guard demoModeStore.isEnabled else { return }
            await demoHarnessState.load(scenario: demoModeStore.scenario)
        }
        .overlay(alignment: .bottomTrailing) {
            DemoLauncherButton(demoModeStore: demoModeStore, harnessState: demoHarnessState, activeRole: $activeRole)
        }
        #endif
    }

    private var signedInPersonID: Identifier<Person>? {
        guard case let .signedIn(user) = authState else { return nil }
        return user.personID
    }

    /// Resolves which role to show and whether the switcher is offered,
    /// gated on the signed-in person's actual `roles` (not just what was
    /// last persisted — see `RoleGating.resolveActiveRole`), then stamps the
    /// resolved role's "last visited" and refreshes the other role's dot.
    private func resolveRoleGating(personID: Identifier<Person>) async {
        let person = try? await container.backend.people.get(personID)
        let roles = person?.roles ?? [.professional]
        availableRoles = roles
        activeRole = RoleGating.resolveActiveRole(roles: roles, persisted: rolePresence.activeRole)
        rolePresence.activeRole = activeRole
        rolePresence.markVisited(activeRole, at: Date())
        await refreshOtherRoleUpdates(signedInPersonID: personID)
    }

    /// The dot on the *other* role's switcher/tab: newer inbound activity
    /// there than the last time that role was visited. Only meaningful for
    /// a both-role person — a single-role person never has an "other role"
    /// to light up.
    private func refreshOtherRoleUpdates(signedInPersonID: Identifier<Person>) async {
        guard RoleGating.switcherAvailable(roles: availableRoles) else {
            otherRoleHasUpdates = false
            return
        }
        let otherRole: PersonRole = activeRole == .professional ? .consumer : .professional
        let latest: Date?
        switch otherRole {
        case .professional:
            latest = await RoleActivitySummary.professionalInboundActivity(backend: container.backend, professionalID: signedInPersonID)
        case .consumer:
            latest = await RoleActivitySummary.consumerInboundActivity(backend: container.backend, clientID: Self.demoClientPersonID)
        }
        otherRoleHasUpdates = RoleActivitySummary.hasUpdates(latestInboundActivity: latest, sinceLastVisited: rolePresence.lastVisited(otherRole))
    }

    private func switchRole(to role: PersonRole) {
        activeRole = role
        rolePresence.activeRole = role
    }

    /// Re-resolves role gating for the signed-in person against the
    /// `Backend` (rather than a stale in-memory value), so a role added via
    /// Settings (`SettingsViewModel.addOtherRole`) unlocks the Prompt-17
    /// role switcher immediately — no reinstall or relaunch required.
    private func refreshRoleGating() {
        guard let personID = signedInPersonID else { return }
        Task { await resolveRoleGating(personID: personID) }
    }

    #if DEBUG
    @ViewBuilder
    private var demoRoot: some View {
        if let bundle = demoHarnessState.bundle {
            switch activeRole {
            case .professional:
                CoachRootView(
                    backend: bundle.backend,
                    professionalID: bundle.professionalID,
                    clock: demoHarnessState.clockController.clock,
                    paymentsMode: .live,
                    onSwitchRole: { activeRole = .consumer }
                )
            case .consumer:
                ConsumerRootView(
                    backend: bundle.backend,
                    clientID: bundle.clientID,
                    clock: demoHarnessState.clockController.clock,
                    paymentsMode: .live,
                    onSwitchRole: { activeRole = .professional }
                )
            }
        } else {
            ProgressView("Loading demo scenario…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Ascend.background)
        }
    }
    #endif

    @ViewBuilder
    private func roleRoot(for user: AuthenticatedUser) -> some View {
        let switcherAvailable = RoleGating.switcherAvailable(roles: availableRoles)
        switch activeRole {
        case .professional:
            CoachRootView(
                backend: container.backend,
                professionalID: user.personID,
                clock: Self.demoClock,
                paymentsMode: container.paymentsMode,
                onSwitchRole: switcherAvailable ? { switchRole(to: .consumer) } : nil,
                otherRoleHasUpdates: otherRoleHasUpdates,
                onRolesChanged: refreshRoleGating
            )
        case .consumer:
            ConsumerRootView(
                backend: container.backend,
                clientID: Self.demoClientPersonID,
                clock: Self.demoClock,
                paymentsMode: container.paymentsMode,
                onSwitchRole: switcherAvailable ? { switchRole(to: .professional) } : nil,
                otherRoleHasUpdates: otherRoleHasUpdates,
                onRolesChanged: refreshRoleGating
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

#Preview {
    RootView()
        .environment(AppContainer.live())
}
