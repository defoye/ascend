import DesignSystem
import Domain
import SwiftUI

/// A `.sheet`-presented flow for assigning (or reassigning) one of the
/// coach's programs to a client engagement: pick a program, choose a start
/// date, and confirm (see docs/design/DESIGN_SPEC.md).
public struct AssignProgramView: View {
    @State private var viewModel: AssignProgramViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: AssignProgramViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    programPicker
                    startDateSection
                    if let saveErrorMessage = viewModel.saveErrorMessage {
                        Text(saveErrorMessage)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.danger)
                            .padding(.horizontal, Spacing.space4)
                    }
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Assign program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton("Assign", isEnabled: viewModel.isValid, isLoading: viewModel.isSaving) {
                    Task {
                        if await viewModel.assign() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
            }
            .task { await viewModel.load() }
        }
    }

    private var programPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Program")
            Card {
                if viewModel.programs.isEmpty {
                    EmptyState(
                        systemImage: "dumbbell",
                        title: "No programs yet",
                        message: "Build a program first, then come back to assign it."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.programs.enumerated()), id: \.element.id) { index, program in
                            if index > 0 {
                                Divider()
                            }
                            programRow(program)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func programRow(_ program: Program) -> some View {
        ListRow(
            title: program.title,
            subtitle: program.summary,
            action: { viewModel.selectedProgramID = program.id },
            leading: { EmptyView() },
            trailing: {
                if viewModel.selectedProgramID == program.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.Ascend.primary)
                }
            }
        )
    }

    private var startDateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Start date")
            Card {
                DatePicker("Start date", selection: $viewModel.startDate, displayedComponents: .date)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("AssignProgramView - Light") {
    AssignProgramPreview()
        .preferredColorScheme(.light)
}

#Preview("AssignProgramView - Dark") {
    AssignProgramPreview()
        .preferredColorScheme(.dark)
}

private struct AssignProgramPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        Text("Assign program preview")
            .sheet(isPresented: .constant(true)) {
                AssignProgramView(
                    viewModel: AssignProgramViewModel(
                        backend: backend,
                        professionalID: professionalID,
                        engagementID: backend.engagementAID
                    )
                )
            }
    }
}
