import DesignSystem
import Domain
import SwiftUI

/// The client's "My Progress" dashboard: their own charts (one
/// `ProgressChart` per tracked metric, reusing the same component and
/// `ProgressViewModel` the coach's `EngagementProgressView` uses) plus
/// milestone/streak tiles computed by `ConsumerProgressSummaries`, and a
/// "Log progress" entry point that writes `.clientSelfReported` entries.
public struct ClientProgressView: View {
    @State private var viewModel: ProgressViewModel
    @State private var showingLogProgress = false
    private let clock: @Sendable () -> Date

    public init(viewModel: ProgressViewModel, clock: @escaping @Sendable () -> Date = { Date() }) {
        _viewModel = State(wrappedValue: viewModel)
        self.clock = clock
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if viewModel.entries.isEmpty {
                    Card {
                        EmptyState(
                            systemImage: "chart.line.uptrend.xyaxis",
                            title: "No progress logged yet",
                            message: "Log a measurement after a workout to start your chart.",
                            actionTitle: "Log progress",
                            action: { showingLogProgress = true }
                        )
                    }
                    .padding(.horizontal, Spacing.space4)
                } else {
                    milestonesSection
                    chartsSection
                    logProgressButton
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("My Progress")
        .sheet(isPresented: $showingLogProgress) {
            LogProgressView(
                viewModel: LogProgressViewModel(
                    backend: viewModel.backend,
                    engagementID: viewModel.engagementID,
                    source: .clientSelfReported,
                    clock: clock
                ),
                onSaved: { Task { await viewModel.load() } }
            )
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        let milestones = ConsumerProgressSummaries.milestones(from: viewModel.entries, now: clock())
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Milestones")
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: Spacing.space3) {
                ForEach(milestones) { milestone in
                    StatTile(label: milestone.label, value: milestone.value)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            SectionHeader("Charts")
            ForEach(viewModel.trackedMetrics, id: \.self) { metric in
                Card {
                    ProgressChart(
                        title: metric.displayName,
                        unit: unitLabel(for: metric),
                        points: viewModel.points(for: metric),
                        lowerIsBetter: metric.lowerIsGenerallyBetter
                    )
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    private var logProgressButton: some View {
        AscendButton("Log progress", variant: .secondary, size: .compact) {
            showingLogProgress = true
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func unitLabel(for metric: MetricKind) -> String {
        viewModel.entries.first { $0.metric == metric }?.value.unit.shortLabel ?? ""
    }
}

#Preview("ClientProgressView - Light") {
    ClientProgressPreview()
        .preferredColorScheme(.light)
}

#Preview("ClientProgressView - Dark") {
    ClientProgressPreview()
        .preferredColorScheme(.dark)
}

private struct ClientProgressPreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        NavigationStack {
            ClientProgressView(
                viewModel: ProgressViewModel(backend: backend, engagementID: backend.engagementAID)
            )
        }
    }
}
