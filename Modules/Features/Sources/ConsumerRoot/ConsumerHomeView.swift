import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The client's "Today" tab: today's assigned workout with a "Start
/// workout" entry point, the next upcoming session, and a nudge from their
/// coach — a calmer, focused daily surface per docs/design/DESIGN_SPEC.md
/// §1 ("the client side is a calmer, focused daily surface").
public struct ConsumerHomeView: View {
    @State private var viewModel: ConsumerHomeViewModel
    @State private var showingWorkoutPlayer = false
    private let backend: any Backend
    private let clock: @Sendable () -> Date

    public init(viewModel: ConsumerHomeViewModel, backend: any Backend, clock: @escaping @Sendable () -> Date = { Date() }) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.clock = clock
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space6) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                if viewModel.engagement != nil {
                    workoutSection
                    sessionSection
                    nudgeSection
                } else if !viewModel.isLoading {
                    Card {
                        EmptyState(
                            systemImage: "figure.strengthtraining.traditional",
                            title: "No coach yet",
                            message: "Once you start working with a coach, your plan will show up here."
                        )
                    }
                    .padding(.horizontal, Spacing.space4)
                }
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Today")
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $showingWorkoutPlayer) {
            if let engagementID = viewModel.engagement?.id, let workout = viewModel.currentWorkout?.workout {
                WorkoutPlayerView(
                    viewModel: WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock)
                )
            }
        }
    }

    // MARK: - Today's workout

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Today's workout")
            Card {
                if let currentWorkout = viewModel.currentWorkout {
                    VStack(alignment: .leading, spacing: Spacing.space3) {
                        VStack(alignment: .leading, spacing: Spacing.space1) {
                            Text(currentWorkout.workout.name)
                                .ascendType(.title3)
                                .foregroundStyle(Color.Ascend.textPrimary)
                            Text("\(viewModel.programTitle ?? "Your program") · Week \(currentWorkout.week.index + 1)")
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: Spacing.space1) {
                            ForEach(currentWorkout.workout.exercises) { exercise in
                                Text("\(exercise.exercise.name) — \(exercise.sets)×\(exercise.reps)")
                                    .ascendType(.footnote)
                                    .foregroundStyle(Color.Ascend.textSecondary)
                            }
                        }
                        AscendButton("Start workout", systemImage: "play.fill") {
                            showingWorkoutPlayer = true
                        }
                    }
                } else {
                    EmptyState(
                        systemImage: "calendar.badge.exclamationmark",
                        title: "No workout assigned yet",
                        message: "Your coach hasn't assigned a program yet — check back soon."
                    )
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Next session

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Next session")
            Card {
                if let nextSession = viewModel.nextSession {
                    ListRow(
                        title: TodaySummaries.relativeDayLabel(for: nextSession.scheduledAt, now: clock()),
                        subtitle: nextSession.scheduledAt.formatted(date: .omitted, time: .shortened),
                        leading: { Image(systemName: "calendar").foregroundStyle(Color.Ascend.primary) },
                        trailing: { EmptyView() }
                    )
                } else {
                    Text("No upcoming sessions scheduled.")
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Coach nudge

    @ViewBuilder
    private var nudgeSection: some View {
        if let nudge = viewModel.coachNudge {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("From \(viewModel.coachName)")
                Card {
                    Text(nudge.body)
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textPrimary)
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }
}

#Preview("ConsumerHomeView - Light") {
    ConsumerHomePreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerHomeView - Dark") {
    ConsumerHomePreview()
        .preferredColorScheme(.dark)
}

private struct ConsumerHomePreview: View {
    var body: some View {
        let backend = PreviewBackend(professionalID: Identifier<Person>())
        NavigationStack {
            ConsumerHomeView(
                viewModel: ConsumerHomeViewModel(backend: backend, clientID: backend.clientAID),
                backend: backend
            )
        }
    }
}
