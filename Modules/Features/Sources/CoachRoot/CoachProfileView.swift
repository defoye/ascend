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
    private let clock: @Sendable () -> Date
    private let onSwitchRole: (() -> Void)?

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        onSwitchRole: (() -> Void)? = nil
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
        self.onSwitchRole = onSwitchRole
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Trust")
                Card {
                    NavigationLink {
                        ProofProfileView(
                            viewModel: ProofProfileViewModel(backend: backend, professionalID: professionalID)
                        )
                    } label: {
                        ListRow(
                            title: "Proof Profile",
                            subtitle: "Verification, stats, and verified client journeys",
                            leading: { Image(systemName: "checkmark.seal").foregroundStyle(Color.Ascend.verified) },
                            trailing: { chevron }
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.space4)

                SectionHeader("Business")
                Card {
                    VStack(spacing: 0) {
                        NavigationLink {
                            ServicePricingView(
                                viewModel: ServicePricingViewModel(backend: backend, professionalID: professionalID)
                            )
                        } label: {
                            ListRow(
                                title: "Services & pricing",
                                subtitle: "Set what you charge for each service",
                                leading: { Image(systemName: "tag").foregroundStyle(Color.Ascend.primary) },
                                trailing: { chevron }
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                        NavigationLink {
                            PaymentHistoryView(
                                viewModel: PaymentHistoryViewModel(backend: backend, professionalID: professionalID, clock: clock),
                                backend: backend,
                                professionalID: professionalID
                            )
                        } label: {
                            ListRow(
                                title: "Payments",
                                subtitle: "Charge clients and view payment history",
                                leading: { Image(systemName: "creditcard").foregroundStyle(Color.Ascend.primary) },
                                trailing: { chevron }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.space4)

                if let onSwitchRole {
                    SectionHeader("Demo")
                    Card {
                        ListRow(
                            title: "Switch to client view",
                            subtitle: "Demo role switch — see the same data as a client",
                            action: onSwitchRole,
                            leading: { Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.Ascend.textSecondary) },
                            trailing: { chevron }
                        )
                    }
                    .padding(.horizontal, Spacing.space4)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Profile")
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .foregroundStyle(Color.Ascend.textTertiary)
            .accessibilityHidden(true)
    }
}

#Preview("CoachProfileView - Light") {
    CoachProfilePreview()
        .preferredColorScheme(.light)
}

#Preview("CoachProfileView - Dark") {
    CoachProfilePreview()
        .preferredColorScheme(.dark)
}

private struct CoachProfilePreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        NavigationStack {
            CoachProfileView(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID)
        }
    }
}
