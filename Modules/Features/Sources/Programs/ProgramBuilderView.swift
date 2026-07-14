import DesignSystem
import Domain
import SwiftUI

/// Create or edit a `Program`: title/summary, and its weeks (add, duplicate,
/// delete, reorder), with each week pushing into `WeekBuilderView` for its
/// workouts. Works both pushed (editing an existing program from
/// `ProgramsListView`'s roster) and sheet-presented (creating a new one),
/// since it doesn't own its own `NavigationStack` (see docs/design/DESIGN_SPEC.md).
public struct ProgramBuilderView: View {
    @State private var viewModel: ProgramBuilderViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: ProgramBuilderViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        List {
            Section("Program details") {
                AscendTextField(label: "Title", placeholder: "e.g. Strength Foundations", text: $viewModel.draft.title)
                AscendTextField(label: "Summary", placeholder: "Short description", text: $viewModel.draft.summary)
            }
            weeksSection
            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.danger)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Ascend.background)
        .navigationTitle(viewModel.isNewProgram ? "New program" : "Edit program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        if await viewModel.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .task { await viewModel.loadExerciseLibrary() }
    }

    private var weeksSection: some View {
        Section("Weeks") {
            ForEach(Array(viewModel.draft.weeks.enumerated()), id: \.element.id) { index, week in
                NavigationLink {
                    WeekBuilderView(viewModel: viewModel, weekID: week.id)
                } label: {
                    weekRow(week, number: index + 1)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        viewModel.duplicateWeek(at: index)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(Color.Ascend.primary)
                }
            }
            .onDelete { viewModel.deleteWeeks(at: $0) }
            .onMove { viewModel.moveWeeks(from: $0, to: $1) }

            Button {
                viewModel.addWeek()
            } label: {
                Label("Add week", systemImage: "plus.circle")
            }
        }
    }

    private func weekRow(_ week: ProgramWeekDraft, number: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text("Week \(number)")
                .ascendType(.headline)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text("\(week.workouts.count) workout\(week.workouts.count == 1 ? "" : "s")")
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }
}

#Preview("ProgramBuilderView - Light") {
    ProgramBuilderPreview()
        .preferredColorScheme(.light)
}

#Preview("ProgramBuilderView - Dark") {
    ProgramBuilderPreview()
        .preferredColorScheme(.dark)
}

private struct ProgramBuilderPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ProgramBuilderView(viewModel: ProgramBuilderViewModel(backend: backend, professionalID: professionalID))
        }
    }
}
