import DesignSystem
import Domain
import PhotosUI
import SwiftUI

/// A single engagement's dedicated Progress screen: one `ProgressChart` per
/// tracked `MetricKind` (filterable by metric), a consent-gated photos
/// section, and a "Log progress" entry point. Pushed from
/// `ClientDetailView`'s Progress section onto the Clients tab's
/// `NavigationStack`.
///
/// Named `EngagementProgressView` (not `ProgressScreen`/`ProgressView`) to
/// avoid colliding with SwiftUI's own `ProgressView`.
public struct EngagementProgressView: View {
    @State var viewModel: ProgressViewModel
    @State var showingLogProgress = false
    // Not `private`: `EngagementProgressView+Photos.swift` (a same-type
    // extension in a different file, split out purely to stay under
    // SwiftLint's `type_body_length`) needs access — `private` is
    // file-scoped in Swift.
    @State var photoPickerItem: PhotosPickerItem?

    public init(viewModel: ProgressViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                chartsSection
                photosSection
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingLogProgress = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log progress")
            }
        }
        .sheet(isPresented: $showingLogProgress) {
            LogProgressView(
                viewModel: LogProgressViewModel(backend: viewModel.backend, engagementID: viewModel.engagementID),
                onSaved: { Task { await viewModel.load() } }
            )
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
    }

    // MARK: - Charts

    @ViewBuilder
    private var chartsSection: some View {
        if viewModel.trackedMetrics.isEmpty {
            Card {
                EmptyState(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No progress logged yet",
                    message: "Progress entries the client (or you) log will show up here.",
                    actionTitle: "Log progress",
                    action: { showingLogProgress = true }
                )
            }
            .padding(.horizontal, Spacing.space4)
        } else {
            VStack(alignment: .leading, spacing: Spacing.space4) {
                filterRow
                ForEach(viewModel.filteredMetrics, id: \.self) { metric in
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
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.space2) {
                Chip("All", style: .filter(isSelected: viewModel.metricFilter == nil)) {
                    viewModel.metricFilter = nil
                }
                ForEach(viewModel.trackedMetrics, id: \.self) { metric in
                    Chip(metric.displayName, style: .filter(isSelected: viewModel.metricFilter == metric)) {
                        viewModel.metricFilter = metric
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func unitLabel(for metric: MetricKind) -> String {
        viewModel.points(for: metric).isEmpty ? "" : entryUnit(for: metric)?.shortLabel ?? ""
    }

    private func entryUnit(for metric: MetricKind) -> MetricUnit? {
        viewModel.entries.first { $0.metric == metric }?.value.unit
    }
}

#Preview("EngagementProgressView - Light") {
    EngagementProgressPreview()
        .preferredColorScheme(.light)
}

#Preview("EngagementProgressView - Dark") {
    EngagementProgressPreview()
        .preferredColorScheme(.dark)
}

private struct EngagementProgressPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            EngagementProgressView(
                viewModel: ProgressViewModel(backend: backend, engagementID: backend.engagementAID)
            )
        }
    }
}
