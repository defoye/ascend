import DesignSystem
import Domain
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The client's workout player: one card per prescribed exercise (sets/reps
/// target, a rest timer, and per-set reps/weight logging), an optional
/// bodyweight check-in, and a "Finish workout" action that persists the
/// evidence described in `WorkoutPlayerViewModel`'s doc comment.
public struct WorkoutPlayerView: View {
    @State private var viewModel: WorkoutPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WorkoutPlayerViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                ForEach(viewModel.workout.exercises) { exercise in
                    exerciseCard(exercise)
                }
                bodyweightCard
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
        .navigationTitle(viewModel.workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            AscendButton(
                "Finish workout",
                isEnabled: viewModel.canComplete,
                isLoading: viewModel.isSaving
            ) {
                Task {
                    if await viewModel.completeWorkout() {
                        fireSuccessHaptic()
                        dismiss()
                    }
                }
            }
            .padding(Spacing.space4)
            .background(Color.Ascend.background)
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
                VStack(spacing: Spacing.space2) {
                    ForEach(viewModel.setLogs(for: exercise)) { log in
                        setRow(log, for: exercise)
                    }
                }
                RestTimerView()
            }
        }
        .padding(.horizontal, Spacing.space4)
    }

    private func setRow(_ log: WorkoutPlayerViewModel.SetLog, for exercise: ExercisePrescription) -> some View {
        HStack(spacing: Spacing.space2) {
            Text("Set \(log.id + 1)")
                .ascendType(.footnote)
                .foregroundStyle(Color.Ascend.textSecondary)
                .frame(width: 50, alignment: .leading)
            AscendTextField(placeholder: "Reps", text: repsBinding(for: log, exercise: exercise))
                .keyboardType(.numberPad)
            AscendTextField(placeholder: "Weight (lb)", text: weightBinding(for: log, exercise: exercise))
                .keyboardType(.decimalPad)
        }
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

    private func fireSuccessHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

/// A minimal rest timer: tap to start a 60-second countdown, per
/// docs/design/DESIGN_SPEC.md §4 ("Rest timer counts down live in the
/// workout player; a subtle pulse + haptic at 0"). Purely local view state —
/// nothing about rest duration is persisted.
private struct RestTimerView: View {
    private static let restDuration: TimeInterval = 60
    @State private var restEndDate: Date?
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let restEndDate {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(restEndDate.timeIntervalSince(context.date).rounded(.up)))
                Text("Rest: \(remaining)s")
                    .ascendType(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color.Ascend.primary)
                    .scaleEffect(pulse ? 1.15 : 1)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.9), value: pulse)
                    .onChange(of: remaining) { _, newValue in
                        guard newValue == 0 else { return }
                        pulse = true
                        fireRestEndHaptic()
                        self.restEndDate = nil
                    }
            }
        } else {
            AscendButton("Start rest timer", variant: .secondary, size: .pill, systemImage: "timer") {
                restEndDate = Date().addingTimeInterval(Self.restDuration)
            }
        }
    }

    private func fireRestEndHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

#Preview("WorkoutPlayerView - Light") {
    WorkoutPlayerPreview()
        .preferredColorScheme(.light)
}

#Preview("WorkoutPlayerView - Dark") {
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
