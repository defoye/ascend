import DesignSystem
import Domain
import SwiftUI

/// A single workout: its name, and its ordered exercise prescriptions (add
/// via `ExercisePickerView`, edit via `PrescriptionEditView`, delete,
/// reorder). Reads and mutates the shared `ProgramBuilderViewModel`'s draft
/// by `weekID`/`workoutID` rather than raw array indices.
struct WorkoutBuilderView: View {
    let viewModel: ProgramBuilderViewModel
    let weekID: Identifier<ProgramWeek>
    let workoutID: Identifier<Workout>

    @State private var showingExercisePicker = false
    @State private var editingPrescription: ExercisePrescriptionDraft?

    private var workout: WorkoutDraft? { viewModel.workout(weekID: weekID, workoutID: workoutID) }

    private var workoutTitle: String {
        let name = workout?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Workout" : name
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { workout?.name ?? "" },
            set: { viewModel.setWorkoutName($0, weekID: weekID, workoutID: workoutID) }
        )
    }

    var body: some View {
        List {
            Section("Workout name") {
                AscendTextField(placeholder: "e.g. Lower Body", text: nameBinding)
            }
            Section("Exercises") {
                ForEach(workout?.exercises ?? []) { prescription in
                    Button {
                        editingPrescription = prescription
                    } label: {
                        prescriptionRow(prescription)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { viewModel.deletePrescriptions(weekID: weekID, workoutID: workoutID, at: $0) }
                .onMove { viewModel.movePrescriptions(weekID: weekID, workoutID: workoutID, from: $0, to: $1) }

                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Ascend.background)
        .navigationTitle(workoutTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView(library: viewModel.exerciseLibrary) { exercise in
                viewModel.addPrescription(exercise, weekID: weekID, workoutID: workoutID)
            }
        }
        .sheet(item: $editingPrescription) { prescription in
            PrescriptionEditView(prescription: prescription) { updated in
                viewModel.updatePrescription(updated, weekID: weekID, workoutID: workoutID)
            }
        }
    }

    private func prescriptionRow(_ prescription: ExercisePrescriptionDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(prescription.exercise.name)
                .ascendType(.headline)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text(prescriptionSubtitle(prescription))
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }

    private func prescriptionSubtitle(_ prescription: ExercisePrescriptionDraft) -> String {
        let base = "\(prescription.sets) sets × \(prescription.reps)"
        return prescription.notes.isEmpty ? base : "\(base) · \(prescription.notes)"
    }
}

#Preview("WorkoutBuilderView - Light") {
    WorkoutBuilderPreview()
        .preferredColorScheme(.light)
}

#Preview("WorkoutBuilderView - Dark") {
    WorkoutBuilderPreview()
        .preferredColorScheme(.dark)
}

private struct WorkoutBuilderPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        let viewModel = ProgramBuilderViewModel(backend: backend, professionalID: professionalID)
        viewModel.addWeek()
        let weekID = viewModel.draft.weeks[0].id
        viewModel.addWorkout(weekID: weekID)
        let workoutID = viewModel.draft.weeks[0].workouts[0].id
        viewModel.addPrescription(Exercise(id: Identifier(), name: "Back Squat"), weekID: weekID, workoutID: workoutID)
        return NavigationStack {
            WorkoutBuilderView(viewModel: viewModel, weekID: weekID, workoutID: workoutID)
        }
    }
}
