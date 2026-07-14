import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's Programs tab: every program they've authored, with a "+" to
/// start a new one in the builder and a row tap to edit an existing one (see
/// docs/design/DESIGN_SPEC.md).
///
/// Expects to be hosted inside a `NavigationStack` supplied by its parent
/// (`CoachRootView`) rather than owning one itself, so row taps can push
/// further onto that same stack.
public struct ProgramsListView: View {
    @State private var viewModel: ProgramsListViewModel
    @State private var showingNewProgram = false
    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(viewModel: ProgramsListViewModel, backend: any Backend, professionalID: Identifier<Person>) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
    }

    public var body: some View {
        content
            .navigationTitle("Programs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewProgram = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New program")
                }
            }
            .sheet(isPresented: $showingNewProgram) {
                NavigationStack {
                    ProgramBuilderView(
                        viewModel: ProgramBuilderViewModel(backend: backend, professionalID: professionalID),
                        onSaved: { Task { await viewModel.load() } }
                    )
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.programs.isEmpty && !viewModel.isLoading {
            VStack(spacing: Spacing.space4) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                EmptyState(
                    systemImage: "dumbbell",
                    title: "No programs yet",
                    message: "Build a training program to assign to your clients.",
                    actionTitle: "Create program",
                    action: { showingNewProgram = true }
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
                    programsCard
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
        }
    }

    private var programsCard: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.programs.enumerated()), id: \.element.id) { index, program in
                    if index > 0 {
                        Divider()
                    }
                    programRow(program)
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func programRow(_ program: Program) -> some View {
        NavigationLink {
            ProgramBuilderView(
                viewModel: ProgramBuilderViewModel(backend: backend, professionalID: professionalID, existingProgram: program),
                onSaved: { Task { await viewModel.load() } }
            )
        } label: {
            ListRow(
                title: program.title,
                subtitle: "\(program.weeks.count) week\(program.weeks.count == 1 ? "" : "s") · \(program.workoutCount) workouts",
                leading: {
                    Image(systemName: "dumbbell")
                        .foregroundStyle(Color.Ascend.primary)
                },
                trailing: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.Ascend.textTertiary)
                        .accessibilityHidden(true)
                }
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("ProgramsListView - Light") {
    ProgramsListPreview()
        .preferredColorScheme(.light)
}

#Preview("ProgramsListView - Dark") {
    ProgramsListPreview()
        .preferredColorScheme(.dark)
}

private struct ProgramsListPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ProgramsListView(
                viewModel: ProgramsListViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }
}
