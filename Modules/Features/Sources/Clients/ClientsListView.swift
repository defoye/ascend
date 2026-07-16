import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's client roster: filterable by `EngagementStatus`, searchable
/// by name, with an "Invite client" flow and a push to `ClientDetailView` per
/// row (see docs/design/DESIGN_SPEC.md).
///
/// Expects to be hosted inside a `NavigationStack` supplied by its parent
/// (`CoachRootView`) rather than owning one itself, so its rows can push
/// further onto that same stack.
public struct ClientsListView: View {
    @State private var viewModel: ClientsListViewModel
    @State private var showingInviteClient = false
    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        viewModel: ClientsListViewModel,
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
    }

    public var body: some View {
        content
            .navigationTitle("Clients")
            .searchable(text: $viewModel.searchText, prompt: "Search clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingInviteClient = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Invite client")
                }
            }
            .sheet(isPresented: $showingInviteClient) {
                InviteClientView(viewModel: InviteClientViewModel(backend: backend, professionalID: professionalID))
                    .presentationDetents([.medium, .large])
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.roster.isEmpty && !viewModel.isLoading {
            VStack(spacing: Spacing.space4) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                EmptyState(
                    systemImage: "person.2",
                    title: "No clients yet",
                    message: "When you start an engagement with a client, it will show up here.",
                    actionTitle: "Invite client",
                    action: { showingInviteClient = true }
                )
            }
            .frame(maxHeight: .infinity)
            .background(Color.Ascend.background)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                            .padding(.horizontal, Spacing.space4)
                    }
                    filterRow
                    rosterCard
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
        }
    }

    // MARK: - Filter row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.space2) {
                Chip("All", style: .filter(isSelected: viewModel.statusFilter == nil)) {
                    viewModel.statusFilter = nil
                }
                ForEach(EngagementStatus.allCases, id: \.self) { status in
                    Chip(status.displayName, style: .filter(isSelected: viewModel.statusFilter == status)) {
                        viewModel.statusFilter = status
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Roster

    @ViewBuilder
    private var rosterCard: some View {
        Card {
            if viewModel.filteredRoster.isEmpty {
                EmptyState(
                    systemImage: "magnifyingglass",
                    title: "No matching clients",
                    message: "Try a different filter or search term."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.filteredRoster.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider()
                        }
                        rosterRow(item)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func rosterRow(_ item: ClientRosterItem) -> some View {
        NavigationLink {
            ClientDetailView(
                viewModel: ClientDetailViewModel(
                    backend: backend,
                    engagementID: item.engagement.id,
                    professionalID: professionalID,
                    clock: clock
                )
            )
        } label: {
            ListRow(
                title: item.clientName,
                subtitle: subtitle(for: item),
                leading: { Avatar(name: item.clientName, size: .md) },
                trailing: {
                    HStack(spacing: Spacing.space2) {
                        statusChip(for: item.status)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.Ascend.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for item: ClientRosterItem) -> String {
        let goal = item.primaryGoal?.displayName ?? "No goal set"
        let activity = item.lastActiveAt.map { $0.formatted(.relative(presentation: .named)) } ?? "No activity yet"
        return "\(goal) · \(activity)"
    }

    private func statusChip(for status: EngagementStatus) -> Chip {
        switch status {
        case .active: Chip(StatusTone.active.rawValue, style: .status(.active))
        case .pending: Chip(StatusTone.pending.rawValue, style: .status(.pending))
        case .paused: Chip(StatusTone.paused.rawValue, style: .status(.paused))
        case .completed: Chip("Completed", style: .filter(isSelected: true))
        case .ended: Chip("Ended", style: .filter(isSelected: false))
        }
    }
}

#Preview("ClientsListView - Light") {
    ClientsListPreview()
        .preferredColorScheme(.light)
}

#Preview("ClientsListView - Dark") {
    ClientsListPreview()
        .preferredColorScheme(.dark)
}

private struct ClientsListPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ClientsListView(
                viewModel: ClientsListViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }
}
