import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// Shared settings screen for both roots (see docs/ROADMAP.md Prompt 16):
/// account, the demo role switch, notification preferences, sign out, and
/// in-app account deletion (required by App Store review guideline 5.1.1(v)
/// for any account-creating app). The same view/view model serve
/// `CoachRootView` and `ConsumerRootView` — nothing here is role-specific.
public struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var reminderScheduler: any SessionReminderScheduling
    @State private var remindersEnabled = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDeletedAlert = false
    @Environment(\.dismiss) private var dismiss

    private let roleLabel: String
    private let onSwitchRole: (() -> Void)?
    private let otherRoleHasUpdates: Bool
    private let otherRoleUpdateSubtitle: String

    public init(
        backend: any Backend,
        personID: Identifier<Person>,
        roleLabel: String,
        reminderScheduler: any SessionReminderScheduling = LiveSessionReminderScheduler(),
        onSwitchRole: (() -> Void)? = nil,
        otherRoleHasUpdates: Bool = false,
        otherRoleUpdateSubtitle: String = "New activity"
    ) {
        _viewModel = State(wrappedValue: SettingsViewModel(backend: backend, personID: personID))
        _reminderScheduler = State(wrappedValue: reminderScheduler)
        self.roleLabel = roleLabel
        self.onSwitchRole = onSwitchRole
        self.otherRoleHasUpdates = otherRoleHasUpdates
        self.otherRoleUpdateSubtitle = otherRoleUpdateSubtitle
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accountSection
                if onSwitchRole != nil {
                    roleSection
                }
                notificationsSection
                privacySection
                accountActionsSection
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Settings")
        .task { await viewModel.load() }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                    showingDeletedAlert = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your profile, engagements, sessions, progress, and payments. This cannot be undone.")
        }
        .alert(
            viewModel.deletionSummary?.personDeleted == true ? "Account deleted" : "Couldn't delete account",
            isPresented: $showingDeletedAlert
        ) {
            Button("OK") {
                if viewModel.deletionSummary?.personDeleted == true {
                    dismiss()
                }
            }
        } message: {
            Text(
                viewModel.deletionSummary?.personDeleted == true
                    ? "Your account and its data have been removed. You've been signed out."
                    : (viewModel.errorMessage ?? "Something went wrong. Try again.")
            )
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Account")
            Card {
                HStack(spacing: Spacing.space3) {
                    Avatar(name: viewModel.displayName.isEmpty ? "You" : viewModel.displayName, size: .md)
                    VStack(alignment: .leading, spacing: Spacing.space1) {
                        Text(viewModel.displayName.isEmpty ? "You" : viewModel.displayName)
                            .ascendType(.headline)
                            .foregroundStyle(Color.Ascend.textPrimary)
                        Text(roleLabel)
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                    Spacer(minLength: Spacing.space2)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    @ViewBuilder
    private var roleSection: some View {
        if let onSwitchRole {
            SectionHeader("Role")
            Card {
                ListRow(
                    title: "Switch role",
                    subtitle: otherRoleHasUpdates
                        ? otherRoleUpdateSubtitle
                        : "Demo role switch — see the same seeded data from the other side",
                    action: onSwitchRole,
                    leading: { Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.Ascend.textSecondary) },
                    trailing: {
                        if otherRoleHasUpdates {
                            Circle()
                                .fill(Color.Ascend.primary)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                        }
                    }
                )
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Notifications")
            Card {
                Toggle(isOn: remindersToggleBinding) {
                    VStack(alignment: .leading, spacing: Spacing.space1) {
                        Text("Session reminders")
                            .ascendType(.headline)
                            .foregroundStyle(Color.Ascend.textPrimary)
                        Text("Get a local reminder an hour before each scheduled session.")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
                .tint(Color.Ascend.primary)
                .frame(minHeight: 44)
                .accessibilityHint("Requests notification permission when turned on")
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var remindersToggleBinding: Binding<Bool> {
        Binding(
            get: { remindersEnabled },
            set: { newValue in
                remindersEnabled = newValue
                guard newValue else { return }
                Task {
                    let granted = await reminderScheduler.requestAuthorization()
                    if !granted { remindersEnabled = false }
                }
            }
        )
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Privacy")
            Card {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    ListRow(
                        title: "Privacy Policy",
                        subtitle: "What we collect and how progress data + photos are protected",
                        leading: { Image(systemName: "hand.raised").foregroundStyle(Color.Ascend.textSecondary) },
                        trailing: {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Color.Ascend.textTertiary)
                                .accessibilityHidden(true)
                        }
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var accountActionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Account actions")
            Card {
                VStack(spacing: Spacing.space3) {
                    AscendButton(
                        "Sign out",
                        variant: .secondary,
                        size: .compact,
                        isLoading: viewModel.isSigningOut
                    ) {
                        Task { await viewModel.signOut() }
                    }
                    .frame(maxWidth: .infinity)

                    AscendButton(
                        "Delete account",
                        variant: .destructiveFilled,
                        size: .compact,
                        isLoading: viewModel.isDeleting
                    ) {
                        showingDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Permanently deletes your account and all associated data")
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("SettingsView - Light") {
    SettingsPreview()
        .preferredColorScheme(.light)
}

#Preview("SettingsView - Dark") {
    SettingsPreview()
        .preferredColorScheme(.dark)
}

#Preview("SettingsView - Both roles, new client activity") {
    SettingsPreview(otherRoleHasUpdates: true)
        .preferredColorScheme(.light)
}

private struct SettingsPreview: View {
    var otherRoleHasUpdates = false

    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        NavigationStack {
            SettingsView(
                backend: backend,
                personID: backend.professionalID,
                roleLabel: "Coach",
                reminderScheduler: MockSessionReminderScheduler(),
                onSwitchRole: {},
                otherRoleHasUpdates: otherRoleHasUpdates,
                otherRoleUpdateSubtitle: "New client activity"
            )
        }
    }
}
