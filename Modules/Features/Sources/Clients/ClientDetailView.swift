import DesignSystem
import Domain
import SwiftUI

/// A single client's detail screen: header (name, editable status), a 2×2
/// stat-tile overview, assigned program summary, a single metric progress
/// chart + recent entries, and coach notes — with a nav-bar message icon
/// into this client's `MessageThreadView` (see docs/design/DESIGN_SPEC.md).
/// Pushed from `ClientsListView` onto the Clients tab's `NavigationStack`.
public struct ClientDetailView: View {
    // Not `private`: `ClientDetailView+Notes.swift` (a same-type extension in
    // a different file, split out purely to stay under SwiftLint's
    // `file_length`) needs access — `private` is file-scoped in Swift.
    @State var viewModel: ClientDetailViewModel
    @State var showingMessageThread = false
    @State private var showingAssignProgram = false
    @State var showingLogProgress = false
    @State var showingFullProgress = false
    @State var editingNoteID: Identifier<CoachNote>?
    @State var editingNoteText = ""

    public init(viewModel: ClientDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                // Error kit (docs/design/handoff/HANDOFF_README.md §06): stale
                // content stays visible under the banner, dimmed to 55%,
                // rather than being replaced or hidden.
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    if viewModel.isLoading {
                        loadingSkeleton
                    } else {
                        header
                        overviewSection
                        programSection
                        progressSection
                        notesSection
                    }
                }
                .opacity(viewModel.loadErrorMessage != nil ? 0.55 : 1)
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle(viewModel.clientName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingMessageThread = true } label: {
                    Image(systemName: "bubble.left")
                }
                .accessibilityLabel("Message \(viewModel.clientName)")
            }
        }
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $showingMessageThread) {
            MessageThreadView(
                viewModel: MessageThreadViewModel(
                    backend: viewModel.backend,
                    engagementID: viewModel.engagementID,
                    selfID: viewModel.professionalID
                )
            )
        }
        .sheet(isPresented: $showingAssignProgram) {
            AssignProgramView(
                viewModel: AssignProgramViewModel(
                    backend: viewModel.backend,
                    professionalID: viewModel.professionalID,
                    engagementID: viewModel.engagementID
                ),
                onSaved: { Task { await viewModel.load() } }
            )
        }
        .sheet(isPresented: $showingLogProgress) {
            LogProgressView(
                viewModel: LogProgressViewModel(backend: viewModel.backend, engagementID: viewModel.engagementID),
                onSaved: { Task { await viewModel.load() } }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.space3) {
                Avatar(name: viewModel.clientName, size: .lg)
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text(viewModel.clientName)
                        .ascendType(.title3)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    statusMenu
                }
                Spacer(minLength: Spacing.space2)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var statusMenu: some View {
        Menu {
            ForEach(EngagementStatus.allCases, id: \.self) { status in
                Button(status.displayName) {
                    Task { await viewModel.setStatus(status) }
                }
            }
        } label: {
            HStack(spacing: Spacing.space1) {
                statusChip
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Color.Ascend.textTertiary)
            }
        }
        .accessibilityLabel("Engagement status: \(viewModel.engagement?.status.displayName ?? "unknown")")
        .accessibilityHint("Double tap to change status")
    }

    @ViewBuilder
    private var statusChip: some View {
        switch viewModel.engagement?.status {
        case .active: Chip(StatusTone.active.rawValue, style: .status(.active))
        case .pending: Chip(StatusTone.pending.rawValue, style: .status(.pending))
        case .paused: Chip(StatusTone.paused.rawValue, style: .status(.paused))
        case .completed: Chip("Completed", style: .filter(isSelected: true))
        case .ended: Chip("Ended", style: .filter(isSelected: false))
        case nil: Chip("Unknown", style: .filter(isSelected: false))
        }
    }

    // MARK: - Overview

    /// A 2×2 grid of `StatTile`s (see docs/design/handoff/HANDOFF_README.md
    /// §02): up to the first two tracked metrics, plus completed sessions
    /// and retention — both derived only from real session data, never a
    /// fixed metric pair or a hardcoded name.
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Overview")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    goalTags
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: Spacing.space3) {
                        ForEach(viewModel.trackedMetrics.prefix(2), id: \.self) { metric in
                            metricStatTile(for: metric)
                        }
                        StatTile(label: "Sessions", value: "\(viewModel.completedSessionsCount)")
                        if let retention = viewModel.sessionRetention {
                            StatTile(label: "Retention", value: "\(retention.percent)", unit: "%")
                        } else {
                            StatTile(label: "Retention", value: "—")
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    @ViewBuilder
    private var goalTags: some View {
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

    private func metricStatTile(for metric: MetricKind) -> some View {
        let points = viewModel.points(for: metric)
        let current = points.last?.value
        return StatTile(
            label: metric.displayName,
            value: current.map { String(format: "%.1f", $0) } ?? "—",
            delta: statDelta(for: points)
        )
    }

    private func statDelta(for points: [ProgressPoint]) -> StatDelta? {
        guard points.count > 1, let first = points.first, let last = points.last else { return nil }
        let change = last.value - first.value
        let text = String(format: "%.1f", abs(change))
        return change >= 0 ? .up(text) : .down(text)
    }

    // MARK: - Program

    private var programSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Program")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space3) {
                    if let program = viewModel.program {
                        VStack(alignment: .leading, spacing: Spacing.space2) {
                            Text(program.title)
                                .ascendType(.headline)
                                .foregroundStyle(Color.Ascend.textPrimary)
                            Text(program.summary)
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textSecondary)
                            Text("\(program.weeks.count) week\(program.weeks.count == 1 ? "" : "s")")
                                .ascendType(.footnote)
                                .foregroundStyle(Color.Ascend.textTertiary)
                        }
                    } else {
                        EmptyState(
                            systemImage: "dumbbell",
                            title: "No program assigned yet",
                            message: "Assign a training program to this client to see it here."
                        )
                    }
                    AscendButton(
                        viewModel.program == nil ? "Assign program" : "Reassign program",
                        variant: .secondary,
                        size: .compact
                    ) {
                        showingAssignProgram = true
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

// MARK: - Progress
//
// Split into an extension (rather than kept in the primary declaration
// above) purely to stay under SwiftLint's `type_body_length` — SwiftLint
// measures each type/extension body independently.
extension ClientDetailView {
    // MARK: - Progress

    /// A single metric chart (see docs/design/handoff/HANDOFF_README.md §02
    /// — one chart, not one per tracked metric), preferring squat 1RM when
    /// tracked. The empty-metrics state (Sam's case) is driven purely off
    /// `progressEntries.isEmpty` — real fetched data, never a hardcoded
    /// client name.
    @ViewBuilder
    var progressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Progress", actionTitle: viewModel.progressEntries.isEmpty ? nil : "See all") {
                showingFullProgress = true
            }
            if viewModel.progressEntries.isEmpty {
                Card {
                    EmptyState(
                        systemImage: "checkmark",
                        title: "No measurements logged yet",
                        message: "Log \(viewModel.clientName)'s first check-in to start the progress record. Charts appear once there are two points.",
                        actionTitle: "Log a check-in",
                        action: { showingLogProgress = true }
                    )
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                primaryProgressChart
                recentEntriesCard
                logProgressButton
            }
        }
        .navigationDestination(isPresented: $showingFullProgress) {
            EngagementProgressView(
                viewModel: ProgressViewModel(backend: viewModel.backend, engagementID: viewModel.engagementID)
            )
        }
    }

    private var logProgressButton: some View {
        AscendButton("Log progress", variant: .secondary, size: .compact) {
            showingLogProgress = true
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var primaryChartMetric: MetricKind? {
        viewModel.trackedMetrics.contains(.squat1RM) ? .squat1RM : viewModel.trackedMetrics.first
    }

    @ViewBuilder
    private var primaryProgressChart: some View {
        if let metric = primaryChartMetric {
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

    private func unitLabel(for metric: MetricKind) -> String {
        progressEntry(for: metric)?.value.unit.shortLabel ?? ""
    }

    private func progressEntry(for metric: MetricKind) -> ProgressEntry? {
        viewModel.progressEntries.first { $0.metric == metric }
    }

    private var recentEntriesCard: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(Array(recentEntries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider()
                    }
                    ListRow(
                        title: entry.metric.displayName,
                        subtitle: entry.recordedAt.formatted(date: .abbreviated, time: .omitted),
                        leading: { EmptyView() },
                        trailing: {
                            Text(MetricFormatter.format(entry.value))
                                .ascendType(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(Color.Ascend.textSecondary)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var recentEntries: [ProgressEntry] {
        Array(viewModel.progressEntries.sorted { $0.recordedAt > $1.recordedAt }.prefix(10))
    }
}

#Preview("ClientDetailView - Light") {
    ClientDetailPreview()
        .preferredColorScheme(.light)
}

#Preview("ClientDetailView - Dark") {
    ClientDetailPreview()
        .preferredColorScheme(.dark)
}

#Preview("ClientDetailView - Empty metrics - Light") {
    ClientDetailPreview(useSecondaryEngagement: true)
        .preferredColorScheme(.light)
}

#Preview("ClientDetailView - Empty metrics - Dark") {
    ClientDetailPreview(useSecondaryEngagement: true)
        .preferredColorScheme(.dark)
}

#Preview("ClientDetailView - Loading - Light") {
    ClientDetailLoadingPreview()
        .preferredColorScheme(.light)
}

#Preview("ClientDetailView - Loading - Dark") {
    ClientDetailLoadingPreview()
        .preferredColorScheme(.dark)
}

private struct ClientDetailPreview: View {
    /// `false` (default) previews "Morgan Chen" — tracked metrics, a
    /// program, notes. `true` previews "Sam Patel" — no progress entries
    /// yet, exercising the empty-metrics state.
    var useSecondaryEngagement = false

    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ClientDetailView(
                viewModel: ClientDetailViewModel(
                    backend: backend,
                    engagementID: useSecondaryEngagement ? backend.engagementBID : backend.engagementAID,
                    professionalID: professionalID
                )
            )
        }
    }
}
