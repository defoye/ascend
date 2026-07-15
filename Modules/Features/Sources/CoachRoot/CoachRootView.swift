import DataInterfaces
import DesignSystem
import Domain
import Foundation
import SwiftUI

/// The coach experience's public entry point: a 5-tab `TabView` per
/// docs/design/DESIGN_SPEC.md §3 (Today, Clients, Programs, Messages,
/// Profile). All five tabs are real screens: Profile hosts services/pricing
/// and payment history (see `CoachProfileView`).
///
/// Takes only `any Backend` + the signed-in professional's identifier (and
/// an optional clock) so the App composition root can wire it without
/// Features ever depending on a concrete backend adapter.
public struct CoachRootView: View {
    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date
    private let paymentsMode: PaymentsMode
    private let onSwitchRole: (() -> Void)?
    private let otherRoleHasUpdates: Bool
    private let onRolesChanged: (() -> Void)?

    @State private var selectedTab: Tab = .today

    private enum Tab: Hashable {
        case today, clients, programs, messages, profile
    }

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        paymentsMode: PaymentsMode = .live,
        onSwitchRole: (() -> Void)? = nil,
        otherRoleHasUpdates: Bool = false,
        onRolesChanged: (() -> Void)? = nil
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
        self.paymentsMode = paymentsMode
        self.onSwitchRole = onSwitchRole
        self.otherRoleHasUpdates = otherRoleHasUpdates
        self.onRolesChanged = onRolesChanged
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                viewModel: TodayViewModel(backend: backend, professionalID: professionalID, paymentsMode: paymentsMode, clock: clock),
                backend: backend,
                professionalID: professionalID,
                now: clock
            )
            .tabItem { Label("Today", systemImage: "calendar") }
            .tag(Tab.today)

            NavigationStack {
                ClientsListView(
                    viewModel: ClientsListViewModel(backend: backend, professionalID: professionalID, clock: clock),
                    backend: backend,
                    professionalID: professionalID,
                    clock: clock
                )
            }
            .tabItem { Label("Clients", systemImage: "person.2") }
            .tag(Tab.clients)

            NavigationStack {
                ProgramsListView(
                    viewModel: ProgramsListViewModel(backend: backend, professionalID: professionalID),
                    backend: backend,
                    professionalID: professionalID
                )
            }
            .tabItem { Label("Programs", systemImage: "dumbbell") }
            .tag(Tab.programs)

            NavigationStack {
                ConversationsListView(
                    viewModel: ConversationsListViewModel(backend: backend, professionalID: professionalID),
                    backend: backend,
                    professionalID: professionalID
                )
            }
            .tabItem { Label("Messages", systemImage: "bubble.left") }
            .tag(Tab.messages)

            NavigationStack {
                CoachProfileView(
                    backend: backend,
                    professionalID: professionalID,
                    clock: clock,
                    paymentsMode: paymentsMode,
                    onSwitchRole: onSwitchRole,
                    otherRoleHasUpdates: otherRoleHasUpdates,
                    onRolesChanged: onRolesChanged
                )
            }
            .tabItem {
                TabIconWithDot(systemName: "person.crop.circle", isSelected: selectedTab == .profile, showDot: otherRoleHasUpdates)
                Text("Profile")
            }
            .tag(Tab.profile)
        }
        .tint(Color.Ascend.primary)
    }
}

#Preview("CoachRootView - Light") {
    CoachRootPreview()
        .preferredColorScheme(.light)
}

#Preview("CoachRootView - Dark") {
    CoachRootPreview()
        .preferredColorScheme(.dark)
}

#Preview("CoachRootView - Both roles, new client activity") {
    CoachRootPreview(otherRoleHasUpdates: true)
        .preferredColorScheme(.light)
}

private struct CoachRootPreview: View {
    var otherRoleHasUpdates = false

    var body: some View {
        let professionalID = Identifier<Person>()
        CoachRootView(
            backend: PreviewBackend(professionalID: professionalID),
            professionalID: professionalID,
            onSwitchRole: otherRoleHasUpdates ? {} : nil,
            otherRoleHasUpdates: otherRoleHasUpdates
        )
    }
}
