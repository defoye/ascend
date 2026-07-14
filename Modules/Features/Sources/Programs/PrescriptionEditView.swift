import DesignSystem
import Domain
import SwiftUI

/// Edits a single `ExercisePrescriptionDraft`'s sets, reps (free text, e.g.
/// "5", "8-12", "45s"), and optional notes. Presented as a sheet both right
/// after picking a new exercise and when tapping an existing prescription row
/// in `WorkoutBuilderView`.
struct PrescriptionEditView: View {
    @State private var draft: ExercisePrescriptionDraft
    @Environment(\.dismiss) private var dismiss
    private let onSave: (ExercisePrescriptionDraft) -> Void

    init(prescription: ExercisePrescriptionDraft, onSave: @escaping (ExercisePrescriptionDraft) -> Void) {
        _draft = State(wrappedValue: prescription)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    exerciseSection
                    setsAndRepsSection
                    notesSection
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Edit exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Exercise")
            Card {
                Text(draft.exercise.name)
                    .ascendType(.headline)
                    .foregroundStyle(Color.Ascend.textPrimary)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var setsAndRepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Sets & reps")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    Stepper("Sets: \(draft.sets)", value: $draft.sets, in: 1...20)
                    AscendTextField(label: "Reps", placeholder: "e.g. 8-12 or 45s", text: $draft.reps)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Notes")
            Card {
                AscendTextField(placeholder: "Optional coaching notes", text: $draft.notes)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

#Preview("PrescriptionEditView - Light") {
    PrescriptionEditPreview()
        .preferredColorScheme(.light)
}

#Preview("PrescriptionEditView - Dark") {
    PrescriptionEditPreview()
        .preferredColorScheme(.dark)
}

private struct PrescriptionEditPreview: View {
    var body: some View {
        PrescriptionEditView(
            prescription: ExercisePrescriptionDraft(
                exercise: Exercise(id: Identifier(), name: "Back Squat"),
                sets: 5,
                reps: "5",
                notes: "Pause 1s at the bottom"
            ),
            onSave: { _ in }
        )
    }
}
