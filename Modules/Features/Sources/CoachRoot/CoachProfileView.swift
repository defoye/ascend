import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's Profile tab: entry points into services/pricing and payment
/// history. Backs `CoachRootView`'s Profile tab (replacing its earlier
/// "Coming soon" placeholder) while keeping the coach tab bar at 5 tabs.
public struct CoachProfileView: View {
    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let paymentsMode: PaymentsMode
    private let onSwitchRole: (() -> Void)?
    private let otherRoleHasUpdates: Bool
    private let onRolesChanged: (() -> Void)?

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        paymentsMode: PaymentsMode = .live,
        onSwitchRole: (() -> Void)? = nil,
        otherRoleHasUpdates: Bool = false,
        onRolesChanged: (() -> Void)? = nil
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.paymentsMode = paymentsMode
        self.onSwitchRole = onSwitchRole
        self.otherRoleHasUpdates = otherRoleHasUpdates
        self.onRolesChanged = onRolesChanged
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Trust")
                Card {
                    NavigationLink {
                        ProofProfileView(
                            viewModel: ProofProfileViewModel(
                                backend: backend,
                                professionalID: professionalID,
                                paymentsMode: paymentsMode
                            )
                        )
                    } label: {
                        ListRow(
                            title: "Proof Profile",
                            subtitle: proofProfileSubtitle,
                            leading: { Image(systemName: "checkmark.seal").foregroundStyle(Color.Ascend.verified) },
                            trailing: { chevron }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.space4)

                SectionHeader("Account")
                Card {
                    NavigationLink {
                        SettingsView(
                            backend: backend,
                            personID: professionalID,
                            roleLabel: "Coach",
                            onSwitchRole: onSwitchRole,
                            otherRoleHasUpdates: otherRoleHasUpdates,
                            otherRoleUpdateSubtitle: "New client activity",
                            onRolesChanged: onRolesChanged
                        )
                    } label: {
                        ListRow(
                            title: "Settings",
                            subtitle: "Notifications, sign out, and account deletion",
                            leading: { Image(systemName: "gearshape").foregroundStyle(Color.Ascend.textSecondary) },
                            trailing: { chevron }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.space4)
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Profile")
    }

    private var proofProfileSubtitle: String {
        switch paymentsMode {
        case .live: "Verification, stats, and verified client journeys"
        case .free: "Verification, stats, and tracked client results"
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .foregroundStyle(Color.Ascend.textTertiary)
            .accessibilityHidden(true)
    }
}

#Preview("CoachProfileView - Live - Light") {
    CoachProfilePreview(paymentsMode: .live)
        .preferredColorScheme(.light)
}

#Preview("CoachProfileView - Live - Dark") {
    CoachProfilePreview(paymentsMode: .live)
        .preferredColorScheme(.dark)
}

#Preview("CoachProfileView - Free - Light") {
    CoachProfilePreview(paymentsMode: .free)
        .preferredColorScheme(.light)
}

#Preview("CoachProfileView - Both roles, new client activity") {
    CoachProfilePreview(paymentsMode: .live, otherRoleHasUpdates: true)
        .preferredColorScheme(.light)
}

private struct CoachProfilePreview: View {
    let paymentsMode: PaymentsMode
    var otherRoleHasUpdates = false

    var body: some View {
        let professionalID = Identifier<Person>()
        NavigationStack {
            CoachProfileView(
                backend: PreviewBackend(professionalID: professionalID),
                professionalID: professionalID,
                paymentsMode: paymentsMode,
                onSwitchRole: otherRoleHasUpdates ? {} : nil,
                otherRoleHasUpdates: otherRoleHasUpdates
            )
        }
    }
}
