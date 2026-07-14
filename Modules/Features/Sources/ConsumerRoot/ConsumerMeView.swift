import DataInterfaces
import DesignSystem
import Domain
import Observation
import SwiftUI

/// View model for `ConsumerMeView`'s profile header: the client's display
/// name and goals, loaded once (this screen's other sections —
/// consent, onboarding — own their own state).
@MainActor
@Observable
final class ConsumerMeViewModel {
    private(set) var displayName = ""
    private(set) var goals: [Goal] = []

    let backend: any Backend
    let clientID: Identifier<Person>

    init(backend: any Backend, clientID: Identifier<Person>) {
        self.backend = backend
        self.clientID = clientID
    }

    func load() async {
        guard let person = try? await backend.people.get(clientID) else { return }
        displayName = person.displayName
        goals = person.goals
    }
}

/// The client's "Me" tab: profile header, the outcome-sharing consent
/// screen (Invariant 1's consent pillar), a way to (re)run goal-first
/// onboarding, and — for this demo build — a way to switch back to the
/// coach view (see docs/design/DESIGN_SPEC.md §4 "Role switch").
public struct ConsumerMeView: View {
    @State private var viewModel: ConsumerMeViewModel
    @State private var showingOnboarding = false
    private let backend: any Backend
    private let clientID: Identifier<Person>
    private let engagementID: Identifier<Engagement>?
    private let clock: @Sendable () -> Date
    private let onSwitchRole: (() -> Void)?

    public init(
        backend: any Backend,
        clientID: Identifier<Person>,
        engagementID: Identifier<Engagement>?,
        clock: @escaping @Sendable () -> Date = { Date() },
        onSwitchRole: (() -> Void)? = nil
    ) {
        _viewModel = State(wrappedValue: ConsumerMeViewModel(backend: backend, clientID: clientID))
        self.backend = backend
        self.clientID = clientID
        self.engagementID = engagementID
        self.clock = clock
        self.onSwitchRole = onSwitchRole
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                header
                consentRow
                onboardingRow
                if let onSwitchRole {
                    switchRoleRow(onSwitchRole)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Me")
        .task { await viewModel.load() }
        .sheet(isPresented: $showingOnboarding) {
            ConsumerOnboardingView(
                viewModel: ConsumerOnboardingViewModel(backend: backend, clientID: clientID, engagementID: engagementID, clock: clock),
                onSaved: { Task { await viewModel.load() } }
            )
        }
    }

    private var header: some View {
        Card {
            HStack(spacing: Spacing.space3) {
                Avatar(name: viewModel.displayName.isEmpty ? "You" : viewModel.displayName, size: .lg)
                VStack(alignment: .leading, spacing: Spacing.space2) {
                    Text(viewModel.displayName.isEmpty ? "You" : viewModel.displayName)
                        .ascendType(.title3)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    if viewModel.goals.isEmpty {
                        Text("No goals set yet.")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    } else {
                        HStack(spacing: Spacing.space2) {
                            ForEach(viewModel.goals) { goal in
                                Chip(goal.kind.displayName, style: .goalTag(dotColor: Color.Ascend.primary))
                            }
                        }
                    }
                }
                Spacer(minLength: Spacing.space2)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    @ViewBuilder
    private var consentRow: some View {
        if let engagementID {
            Card {
                NavigationLink {
                    ConsentView(viewModel: ConsentViewModel(backend: backend, engagementID: engagementID))
                } label: {
                    ListRow(
                        title: "Share progress",
                        subtitle: "Control whether your progress counts toward verified journeys",
                        leading: { Image(systemName: "checkmark.seal").foregroundStyle(Color.Ascend.verified) },
                        trailing: { chevron }
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var onboardingRow: some View {
        Card {
            ListRow(
                title: "Update your goals",
                subtitle: "Retake your intake — goal, experience, injuries, preferences",
                action: { showingOnboarding = true },
                leading: { Image(systemName: "target").foregroundStyle(Color.Ascend.primary) },
                trailing: { chevron }
            )
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func switchRoleRow(_ action: @escaping () -> Void) -> some View {
        Card {
            ListRow(
                title: "Switch to coach view",
                subtitle: "Demo role switch — see the same data as the professional",
                action: action,
                leading: { Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.Ascend.textSecondary) },
                trailing: { chevron }
            )
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .foregroundStyle(Color.Ascend.textTertiary)
            .accessibilityHidden(true)
    }
}

#Preview("ConsumerMeView - Light") {
    ConsumerMePreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerMeView - Dark") {
    ConsumerMePreview()
        .preferredColorScheme(.dark)
}

private struct ConsumerMePreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        NavigationStack {
            ConsumerMeView(
                backend: backend,
                clientID: backend.clientAID,
                engagementID: backend.engagementAID,
                onSwitchRole: {}
            )
        }
    }
}
