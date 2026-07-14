import DesignSystem
import Domain
import SwiftUI

/// A single week's workouts: add, delete, and reorder, with each workout
/// pushing into `WorkoutBuilderView` for its exercise prescriptions. Reads
/// and mutates the shared `ProgramBuilderViewModel`'s draft by `weekID`
/// rather than a raw array index, so it stays correct even if the parent
/// week list is edited concurrently.
struct WeekBuilderView: View {
    let viewModel: ProgramBuilderViewModel
    let weekID: Identifier<ProgramWeek>

    private var week: ProgramWeekDraft? { viewModel.week(withID: weekID) }
    private var weekNumber: Int { (viewModel.weekIndex(withID: weekID) ?? 0) + 1 }

    var body: some View {
        List {
            Section("Workouts") {
                ForEach(week?.workouts ?? []) { workout in
                    NavigationLink {
                        WorkoutBuilderView(viewModel: viewModel, weekID: weekID, workoutID: workout.id)
                    } label: {
                        workoutRow(workout)
                    }
                }
                .onDelete { viewModel.deleteWorkouts(weekID: weekID, at: $0) }
                .onMove { viewModel.moveWorkouts(weekID: weekID, from: $0, to: $1) }

                Button {
                    viewModel.addWorkout(weekID: weekID)
                } label: {
                    Label("Add workout", systemImage: "plus.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Ascend.background)
        .navigationTitle("Week \(weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        }
    }

    private func workoutRow(_ workout: WorkoutDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(workout.name.isEmpty ? "Untitled workout" : workout.name)
                .ascendType(.headline)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text("\(workout.exercises.count) exercise\(workout.exercises.count == 1 ? "" : "s")")
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }
}

#Preview("WeekBuilderView - Light") {
    WeekBuilderPreview()
        .preferredColorScheme(.light)
}

#Preview("WeekBuilderView - Dark") {
    WeekBuilderPreview()
        .preferredColorScheme(.dark)
}

private struct WeekBuilderPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        let viewModel = ProgramBuilderViewModel(backend: backend, professionalID: professionalID)
        viewModel.addWeek()
        let weekID = viewModel.draft.weeks[0].id
        viewModel.addWorkout(weekID: weekID)
        return NavigationStack {
            WeekBuilderView(viewModel: viewModel, weekID: weekID)
        }
    }
}
