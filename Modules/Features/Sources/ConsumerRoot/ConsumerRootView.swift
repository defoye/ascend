import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The client experience's public entry point: a 4-tab `TabView` per
/// docs/design/DESIGN_SPEC.md §3 (Today, Progress, Coach, Me) — a calmer,
/// lighter-chrome counterpart to `CoachRootView`'s 5-tab business toolkit,
/// built on the exact same repositories/`Domain` types (see
/// docs/ARCHITECTURE.md).
///
/// Takes only `any Backend` + the signed-in client's identifier (and an
/// optional clock), mirroring `CoachRootView`, so the App composition root
/// can wire it without `Features` ever depending on a concrete backend
/// adapter. Resolves the client's primary engagement itself
/// (`ConsumerProgramSummaries.primaryEngagement`) before showing the tab
/// bar, so a client with no coach yet sees a graceful empty state instead
/// of a broken/partial tab bar.
public struct ConsumerRootView: View {
    private let backend: any Backend
    private let clientID: Identifier<Person>
    private let clock: @Sendable () -> Date
    private let onSwitchRole: (() -> Void)?

    @State private var engagement: Engagement?
    @State private var isResolvingEngagement = true

    public init(
        backend: any Backend,
        clientID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        onSwitchRole: (() -> Void)? = nil
    ) {
        self.backend = backend
        self.clientID = clientID
        self.clock = clock
        self.onSwitchRole = onSwitchRole
    }

    public var body: some View {
        Group {
            if let engagement {
                tabs(engagement: engagement)
            } else if isResolvingEngagement {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.Ascend.background)
            } else {
                noCoachState
            }
        }
        .task { await resolveEngagement() }
    }

    private func resolveEngagement() async {
        let engagements = (try? await backend.engagements.fetchEngagements(forClient: clientID)) ?? []
        engagement = ConsumerProgramSummaries.primaryEngagement(engagements)
        isResolvingEngagement = false
    }

    private var noCoachState: some View {
        NavigationStack {
            ScrollView {
                Card {
                    EmptyState(
                        systemImage: "person.crop.circle.badge.questionmark",
                        title: "No coach yet",
                        message: "Once you start working with a coach, your Today, Progress, and messages will show up here."
                    )
                }
                .padding(Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Ascend")
        }
    }

    @ViewBuilder
    private func tabs(engagement: Engagement) -> some View {
        TabView {
            NavigationStack {
                ConsumerHomeView(
                    viewModel: ConsumerHomeViewModel(backend: backend, clientID: clientID, clock: clock),
                    backend: backend,
                    clock: clock
                )
            }
            .tabItem { Label("Today", systemImage: "sun.max") }

            NavigationStack {
                ClientProgressView(
                    viewModel: ProgressViewModel(backend: backend, engagementID: engagement.id),
                    clock: clock
                )
            }
            .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                MessageThreadView(
                    viewModel: MessageThreadViewModel(backend: backend, engagementID: engagement.id, selfID: clientID)
                )
            }
            .tabItem { Label("Coach", systemImage: "bubble.left") }

            NavigationStack {
                ConsumerMeView(
                    backend: backend,
                    clientID: clientID,
                    engagementID: engagement.id,
                    clock: clock,
                    onSwitchRole: onSwitchRole
                )
            }
            .tabItem { Label("Me", systemImage: "person.crop.circle") }
        }
        .tint(Color.Ascend.primary)
    }
}

#Preview("ConsumerRootView - Light") {
    ConsumerRootPreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerRootView - Dark") {
    ConsumerRootPreview()
        .preferredColorScheme(.dark)
}

private struct ConsumerRootPreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        ConsumerRootView(backend: backend, clientID: backend.clientAID)
    }
}
