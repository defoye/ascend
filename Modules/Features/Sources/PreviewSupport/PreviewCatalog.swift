import DataInterfaces
import Domain
import SwiftUI

/// A single-canvas "contact sheet" of the app's core screens across both
/// roles, each framed at device size, so one preview shows the whole surface
/// at once — pair it with the two `#Preview`s below to sweep the app in light
/// and dark without opening every screen file.
///
/// Scope: the primary happy-path screen per area, built from the same
/// `PreviewBackend` fixture the per-file previews use. Edge states (loading,
/// empty, error, alternate modes) deliberately stay in their per-file
/// `#Preview`s — enumerate those with a Find-navigator search for `#Preview`.
/// When a screen's construction changes, update the matching builder here too.
struct PreviewCatalog: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                card("Sign in", role: "Onboarding") { authScreen }
                card("Today", role: "Coach") { todayScreen }
                card("Clients", role: "Coach") { clientsScreen }
                card("Client detail", role: "Coach") { clientDetailScreen }
                card("Programs", role: "Coach") { programsScreen }
                card("Schedule", role: "Coach") { scheduleScreen }
                card("Proof profile", role: "Coach") { proofScreen }
                card("Settings", role: "Coach") { settingsScreen }
                card("Home", role: "Client") { consumerHomeScreen }
            }
            .padding(24)
        }
    }

    // MARK: - Card chrome

    private func card(_ title: String, role: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(role)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.secondary.opacity(0.18)))
            }
            content()
                .frame(width: 393, height: 852)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.secondary.opacity(0.3)))
        }
    }

    // MARK: - Screen builders (mirror each screen's own #Preview construction)

    private var authScreen: some View {
        AuthView(viewModel: AuthViewModel(auth: PreviewAuthGateway()))
    }

    private var todayScreen: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        return TodayView(
            viewModel: TodayViewModel(backend: backend, professionalID: professionalID, paymentsMode: .live),
            backend: backend,
            professionalID: professionalID,
            reminders: MockSessionReminderScheduler()
        )
    }

    private var clientsScreen: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        return NavigationStack {
            ClientsListView(
                viewModel: ClientsListViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }

    private var clientDetailScreen: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        return NavigationStack {
            ClientDetailView(
                viewModel: ClientDetailViewModel(
                    backend: backend,
                    engagementID: backend.engagementAID,
                    professionalID: professionalID
                )
            )
        }
    }

    private var programsScreen: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        return NavigationStack {
            ProgramsListView(
                viewModel: ProgramsListViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }

    private var scheduleScreen: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        let viewModel = ScheduleViewModel(
            backend: backend,
            professionalID: professionalID,
            clock: { Date() },
            reminders: MockSessionReminderScheduler()
        )
        return NavigationStack {
            ScheduleView(
                viewModel: viewModel,
                backend: backend,
                professionalID: professionalID,
                reminders: MockSessionReminderScheduler()
            )
        }
    }

    private var proofScreen: some View {
        let professionalID = Identifier<Person>()
        return NavigationStack {
            ProofProfileView(
                viewModel: ProofProfileViewModel(
                    backend: PreviewBackend(professionalID: professionalID),
                    professionalID: professionalID,
                    paymentsMode: .live
                )
            )
        }
    }

    private var settingsScreen: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        return NavigationStack {
            SettingsView(
                backend: backend,
                personID: backend.professionalID,
                roleLabel: "Coach",
                reminderScheduler: MockSessionReminderScheduler(),
                onSwitchRole: {},
                otherRoleHasUpdates: false,
                otherRoleUpdateSubtitle: "New client activity"
            )
        }
    }

    private var consumerHomeScreen: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        return NavigationStack {
            ConsumerHomeView(
                viewModel: ConsumerHomeViewModel(backend: backend, clientID: backend.clientAID),
                backend: backend
            )
        }
    }
}

#Preview("Screen Catalog — Light") {
    PreviewCatalog()
        .preferredColorScheme(.light)
}

#Preview("Screen Catalog — Dark") {
    PreviewCatalog()
        .preferredColorScheme(.dark)
}
