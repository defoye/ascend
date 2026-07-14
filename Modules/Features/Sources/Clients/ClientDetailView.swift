import DesignSystem
import Domain
import SwiftUI

/// A single client's detail screen: header (name, goal, editable status),
/// goals/metrics overview, assigned program summary, per-metric progress
/// charts + recent entries, coach notes, and a stubbed message shortcut
/// (see docs/design/DESIGN_SPEC.md). Pushed from `ClientsListView` onto the
/// Clients tab's `NavigationStack`.
public struct ClientDetailView: View {
    // Not `private`: `ClientDetailView+Notes.swift` (a same-type extension in
    // a different file, split out purely to stay under SwiftLint's
    // `file_length`) needs access — `private` is file-scoped in Swift.
    @State var viewModel: ClientDetailViewModel
    @State var showingMessageStub = false
    @State private var showingAssignProgram = false
    @State var editingNoteID: Identifier<CoachNote>?
    @State var editingNoteText = ""

    public init(viewModel: ClientDetailViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                header
                overviewSection
                programSection
                progressSection
                notesSection
                messageShortcut
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle(viewModel.clientName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .alert("Messaging coming soon", isPresented: $showingMessageStub) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chat with \(viewModel.clientName) will be available in a future update.")
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
    }

    // MARK: - Header

    private var header: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space3) {
                HStack(spacing: Spacing.space3) {
                    Avatar(name: viewModel.clientName, size: .lg)
                    VStack(alignment: .leading, spacing: Spacing.space1) {
                        Text(viewModel.clientName)
                            .ascendType(.title3)
                            .foregroundStyle(Color.Ascend.textPrimary)
                        if let goal = viewModel.goals.first {
                            Text(goal.kind.displayName)
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textSecondary)
                        }
                    }
                    Spacer(minLength: Spacing.space2)
                }
                statusMenu
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

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Overview")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    goalTags
                    if !viewModel.trackedMetrics.isEmpty {
                        let columns = [GridItem(.flexible()), GridItem(.flexible())]
                        LazyVGrid(columns: columns, spacing: Spacing.space3) {
                            ForEach(viewModel.trackedMetrics, id: \.self) { metric in
                                metricStatTile(for: metric)
                            }
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

// MARK: - Progress, notes, and message shortcut
//
// Split into an extension (rather than kept in the primary declaration
// above) purely to stay under SwiftLint's `type_body_length` — SwiftLint
// measures each type/extension body independently.
extension ClientDetailView {
    // MARK: - Progress

    @ViewBuilder
    var progressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Progress")
            if viewModel.progressEntries.isEmpty {
                Card {
                    EmptyState(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "No progress logged yet",
                        message: "Progress entries the client (or you) log will show up here."
                    )
                }
                .padding(.horizontal, Spacing.space4)
            } else {
                progressCharts
                recentEntriesCard
            }
        }
    }

    private var progressCharts: some View {
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

private struct ClientDetailPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ClientDetailView(
                viewModel: ClientDetailViewModel(
                    backend: backend,
                    engagementID: backend.engagementAID,
                    professionalID: professionalID
                )
            )
        }
    }
}
