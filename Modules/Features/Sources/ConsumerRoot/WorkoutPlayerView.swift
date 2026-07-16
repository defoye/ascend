import DesignSystem
import Domain
import SwiftUI

/// The client's workout player: header + segmented exercise-progress bar,
/// one card per prescribed exercise (sets/reps target, a "Last time"
/// reference chip when history exists, per-set logging with a live rest
/// timer between sets), an optional bodyweight check-in, and a
/// "Finish workout" action that persists the evidence described in
/// `WorkoutPlayerViewModel`'s doc comment and hands off to the
/// `WorkoutCompleteView` summary (see docs/design/handoff/
/// HANDOFF_README.md §05 "Consumer — Workout Player").
public struct WorkoutPlayerView: View {
    @State private var viewModel: WorkoutPlayerViewModel
    @State private var restEndDateByExercise: [Identifier<ExercisePrescription>: Date] = [:]
    @State private var confirmationByExercise: [Identifier<ExercisePrescription>: SetConfirmation] = [:]
    @Environment(\.dismiss) private var dismiss

    private static let restDuration: TimeInterval = 60

    public init(viewModel: WorkoutPlayerViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if viewModel.isCompleted {
                WorkoutCompleteView(
                    workoutName: viewModel.workout.name,
                    totals: viewModel.sessionTotals,
                    comparison: viewModel.topSetComparison,
                    onDone: { dismiss() }
                )
            } else {
                player
            }
        }
        .task { await viewModel.loadHistory() }
    }

    private var player: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                header
                ForEach(viewModel.workout.exercises) { exercise in
                    exerciseCard(exercise)
                }
                bodyweightCard
                if let saveErrorMessage = viewModel.saveErrorMessage {
                    ErrorBanner(message: saveErrorMessage)
                        .padding(.horizontal, Spacing.space4)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            AscendButton(
                "Finish workout",
                isEnabled: viewModel.canComplete,
                isLoading: viewModel.isSaving
            ) {
                Task {
                    if await viewModel.completeWorkout() {
                        AscendHaptics.success()
                    }
                }
            }
            .padding(Spacing.space4)
            .background(Color.Ascend.background)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.space3) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Ascend.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.Ascend.surfaceSecondary))
                }
                .accessibilityLabel("Close workout")
                Spacer(minLength: Spacing.space2)
                VStack(spacing: Spacing.space1) {
                    Text(viewModel.workout.name)
                        .ascendType(.headline)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    Text("EXERCISE \(viewModel.currentExerciseIndex + 1) / \(viewModel.workout.exercises.count)")
                        .ascendDataLabel()
                        .foregroundStyle(Color.Ascend.textTertiary)
                }
                Spacer(minLength: Spacing.space2)
                TimelineView(.periodic(from: viewModel.startedAt, by: 1)) { context in
                    Text(ConsumerProgramSummaries.formattedDuration(context.date.timeIntervalSince(viewModel.startedAt)))
                        .ascendType(.footnote)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color.Ascend.textSecondary)
                        .frame(width: 46, alignment: .trailing)
                }
                .accessibilityHidden(true)
            }
            progressBar
        }
        .padding(.horizontal, Spacing.space4)
    }

    private var progressBar: some View {
        HStack(spacing: Spacing.space1) {
            ForEach(Array(viewModel.workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(segmentColor(index: index, exercise: exercise))
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func segmentColor(index: Int, exercise: ExercisePrescription) -> Color {
        if viewModel.isExerciseFullyLogged(exercise) {
            Color.Ascend.success
        } else if index == viewModel.currentExerciseIndex {
            Color.Ascend.primary
        } else {
            Color.Ascend.surfaceSecondary
        }
    }

    // MARK: - Exercises

    private func exerciseCard(_ exercise: ExercisePrescription) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space4) {
                VStack(alignment: .leading, spacing: Spacing.space1) {
                    Text(exercise.exercise.name)
                        .ascendType(.headline)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    Text("\(exercise.sets) sets × \(exercise.reps) reps")
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textSecondary)
                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.textTertiary)
                    }
                }
                if let lastEntry = viewModel.lastLoggedEntry(for: exercise) {
                    lastTimeChip(lastEntry)
                }
                VStack(spacing: Spacing.space2) {
                    ForEach(viewModel.setLogs(for: exercise)) { log in
                        setRow(log, for: exercise)
                    }
                }
                exerciseFooter(exercise)
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func lastTimeChip(_ entry: ProgressEntry) -> some View {
        HStack(spacing: Spacing.space1) {
            Image(systemName: "clock")
                .foregroundStyle(Color.Ascend.textSecondary)
            Text("Last time:")
                .ascendType(.footnote)
                .foregroundStyle(Color.Ascend.textSecondary)
            Text("\(formattedWeight(entry.value.value)) \(entry.value.unit.shortLabel)")
                .ascendType(.footnote)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Color.Ascend.textPrimary)
        }
        .padding(.horizontal, Spacing.space3)
        .frame(minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.Ascend.surfaceSecondary)
        )
        .accessibilityElement(children: .combine)
    }

    private func setRow(_ log: WorkoutPlayerViewModel.SetLog, for exercise: ExercisePrescription) -> some View {
        let state = viewModel.setRowState(log, for: exercise)
        return HStack(spacing: Spacing.space2) {
            HStack(spacing: Spacing.space1) {
                if state == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.Ascend.success)
                }
                Text("Set \(log.id + 1)")
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.textSecondary)
            }
            .frame(width: 64, alignment: .leading)
            AscendTextField(placeholder: "Reps", text: repsBinding(for: log, exercise: exercise))
                .keyboardType(.numberPad)
                .disabled(state == .done)
            AscendTextField(placeholder: "Weight (lb)", text: weightBinding(for: log, exercise: exercise))
                .keyboardType(.decimalPad)
                .disabled(state == .done)
        }
        .padding(Spacing.space2)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(state == .done ? Color.Ascend.success.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(state == .active ? Color.Ascend.primary : .clear, lineWidth: 1.5)
        )
        .opacity(state == .pending ? 0.5 : 1)
    }

    @ViewBuilder
    private func exerciseFooter(_ exercise: ExercisePrescription) -> some View {
        if restEndDateByExercise[exercise.id] != nil {
            let confirmation = confirmationByExercise[exercise.id]
            RestTimerView(
                restDuration: Self.restDuration,
                restEndDate: restEndDateBinding(for: exercise),
                setNumber: confirmation?.setNumber ?? 0,
                confirmationValue: confirmation?.value ?? "",
                confirmationDelta: confirmation?.delta ?? "",
                nextSetNumber: (confirmation?.setNumber ?? 0) + 1
            )
        } else if viewModel.isExerciseFullyLogged(exercise), let confirmation = confirmationByExercise[exercise.id] {
            LoggedConfirmation(value: confirmation.value, delta: confirmation.delta)
        } else if let active = viewModel.setLogs(for: exercise).first(where: { !$0.logged }) {
            AscendButton(
                "Log set \(active.id + 1)",
                isEnabled: !active.reps.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                logSet(for: exercise)
            }
        }
    }

    /// Commits the exercise's active set, records its confirmation copy, and
    /// — when another set remains — starts that exercise's rest timer. The
    /// committed set's `LoggedConfirmation` renders exactly once: either
    /// inline (final set of the exercise) or as the rest timer's
    /// confirmation chip (a set remains) — never both, so exactly one
    /// success haptic fires per commit.
    private func logSet(for exercise: ExercisePrescription) {
        guard let committed = viewModel.commitActiveSet(for: exercise) else { return }
        let copy = viewModel.confirmationCopy(for: committed, exercise: exercise)
        confirmationByExercise[exercise.id] = SetConfirmation(setNumber: committed.id + 1, value: copy.value, delta: copy.delta)

        let hasNextSet = viewModel.setLogs(for: exercise).contains { !$0.logged }
        if hasNextSet {
            restEndDateByExercise[exercise.id] = Date().addingTimeInterval(Self.restDuration)
        }
    }

    private func restEndDateBinding(for exercise: ExercisePrescription) -> Binding<Date?> {
        Binding(
            get: { restEndDateByExercise[exercise.id] },
            set: { restEndDateByExercise[exercise.id] = $0 }
        )
    }

    private func repsBinding(for log: WorkoutPlayerViewModel.SetLog, exercise: ExercisePrescription) -> Binding<String> {
        Binding(
            get: { log.reps },
            set: { newValue in
                var updated = log
                updated.reps = newValue
                viewModel.updateSetLog(updated, for: exercise)
            }
        )
    }

    private func weightBinding(for log: WorkoutPlayerViewModel.SetLog, exercise: ExercisePrescription) -> Binding<String> {
        Binding(
            get: { log.weightText },
            set: { newValue in
                var updated = log
                updated.weightText = newValue
                viewModel.updateSetLog(updated, for: exercise)
            }
        )
    }

    // MARK: - Bodyweight check-in

    private var bodyweightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Today's weigh-in")
            Card {
                AscendTextField(
                    placeholder: "Weight (lb), optional",
                    text: $viewModel.bodyweightText,
                    helperText: "Logging a number here or on any set above is what saves your progress."
                )
                .keyboardType(.decimalPad)
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

/// The just-committed set's confirmation copy, kept alongside a per-exercise
/// rest timer so both the inline (final-set) and rest-timer (mid-exercise)
/// confirmation paths can render the same `LoggedConfirmation` content.
private struct SetConfirmation: Equatable {
    let setNumber: Int
    let value: String
    let delta: String
}

private func formattedWeight(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
}

#Preview("WorkoutPlayerView - Active logging - Light") {
    WorkoutPlayerPreview()
        .preferredColorScheme(.light)
}

#Preview("WorkoutPlayerView - Active logging - Dark") {
    WorkoutPlayerPreview()
        .preferredColorScheme(.dark)
}

private struct WorkoutPlayerPreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        let workout = Workout(
            id: Identifier(),
            name: "Lower Body",
            exercises: [
                ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Back Squat"), sets: 3, reps: "5", notes: nil),
                ExercisePrescription(id: Identifier(), exercise: Exercise(id: Identifier(), name: "Walking Lunge"), sets: 3, reps: "12", notes: "Alternating legs")
            ]
        )
        NavigationStack {
            WorkoutPlayerView(
                viewModel: WorkoutPlayerViewModel(backend: backend, engagementID: backend.engagementAID, workout: workout)
            )
        }
    }
}
