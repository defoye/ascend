import DesignSystem
import Domain
import SwiftUI

/// A `.sheet`-presented flow for starting a new coaching relationship:
/// either create a lightweight new client record, or invite/select an
/// existing `.consumer` person (see docs/design/DESIGN_SPEC.md).
public struct AddClientView: View {
    @State private var viewModel: AddClientViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    public init(viewModel: AddClientViewModel, onSaved: @escaping () -> Void = {}) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    modePicker
                    switch viewModel.mode {
                    case .newPerson: newPersonSection
                    case .existingPerson: existingPersonSection
                    }
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
            .navigationTitle("Add client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                AscendButton(
                    "Add client",
                    isEnabled: viewModel.isValid,
                    isLoading: viewModel.isSaving
                ) {
                    Task {
                        if await viewModel.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
            }
            .task { await viewModel.loadExistingCandidates() }
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: Spacing.space2) {
            Chip("New client", style: .filter(isSelected: viewModel.mode == .newPerson)) {
                viewModel.mode = .newPerson
            }
            Chip("Existing person", style: .filter(isSelected: viewModel.mode == .existingPerson)) {
                viewModel.mode = .existingPerson
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    // MARK: - New person

    private var newPersonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Client details")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    AscendTextField(label: "Full name", placeholder: "Jordan Lee", text: $viewModel.name)
                    goalPicker
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Text("Starting goal (optional)")
                .ascendType(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Ascend.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.space2) {
                    ForEach(GoalKind.allCases, id: \.self) { kind in
                        Chip(kind.displayName, style: .filter(isSelected: viewModel.selectedGoalKind == kind)) {
                            viewModel.selectedGoalKind = viewModel.selectedGoalKind == kind ? nil : kind
                        }
                    }
                }
            }
        }
    }

    // MARK: - Existing person

    @ViewBuilder
    private var existingPersonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Select a person")
            Card {
                if viewModel.existingCandidates.isEmpty {
                    EmptyState(
                        systemImage: "person.crop.circle.badge.questionmark",
                        title: "No eligible people",
                        message: "Everyone with a client account is already engaged with you, or none exist yet."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.existingCandidates.enumerated()), id: \.element.id) { index, person in
                            if index > 0 {
                                Divider()
                            }
                            existingPersonRow(person)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func existingPersonRow(_ person: Person) -> some View {
        ListRow(
            title: person.displayName,
            subtitle: person.goals.first?.kind.displayName,
            action: { viewModel.selectedExistingPersonID = person.id },
            leading: { Avatar(name: person.displayName, size: .md) },
            trailing: {
                if viewModel.selectedExistingPersonID == person.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.Ascend.primary)
                }
            }
        )
    }
}

#Preview("AddClientView - Light") {
    AddClientPreview()
        .preferredColorScheme(.light)
}

#Preview("AddClientView - Dark") {
    AddClientPreview()
        .preferredColorScheme(.dark)
}

private struct AddClientPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        AddClientView(viewModel: AddClientViewModel(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID))
    }
}
