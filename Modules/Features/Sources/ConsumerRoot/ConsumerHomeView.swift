import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The client's "Today" tab: a hero card for today's assigned workout with a
/// "Start workout" entry point, the next upcoming session, a nudge from
/// their coach, and a bodyweight trend chart — a calmer, focused daily
/// surface per docs/design/DESIGN_SPEC.md §1 ("the client side is a calmer,
/// focused daily surface") and docs/design/handoff/HANDOFF_README.md §04.
public struct ConsumerHomeView: View {
    // Not `private`: `ConsumerHomeView+Skeleton.swift` (a same-type
    // extension in a different file, split out purely to stay under
    // SwiftLint's `file_length`) needs access — `private` is file-scoped in
    // Swift.
    @State var viewModel: ConsumerHomeViewModel
    @State private var showingWorkoutPlayer = false
    @State private var showingLogBodyweight = false
    private let backend: any Backend
    let clock: @Sendable () -> Date

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
                // Error kit (docs/design/handoff/HANDOFF_README.md §06):
                // stale content (header included) stays visible under the
                // banner, dimmed to 55%, rather than being replaced or hidden.
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    header
                    stateContent
                }
                .opacity(viewModel.loadErrorMessage != nil ? 0.55 : 1)
            }
            .padding(.vertical, Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task { await viewModel.load() }
        .navigationDestination(isPresented: $showingWorkoutPlayer) {
            if let engagementID = viewModel.engagement?.id, let workout = viewModel.currentWorkout?.workout {
                WorkoutPlayerView(
                    viewModel: WorkoutPlayerViewModel(backend: backend, engagementID: engagementID, workout: workout, clock: clock)
                )
            }
        }
        .sheet(isPresented: $showingLogBodyweight) {
            if let engagementID = viewModel.engagement?.id {
                LogProgressView(
                    viewModel: LogProgressViewModel(
                        backend: backend,
                        engagementID: engagementID,
                        metric: .bodyweight,
                        source: .clientSelfReported,
                        clock: clock
                    ),
                    onSaved: { Task { await viewModel.load() } }
                )
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        if viewModel.isLoading {
            loadingSkeleton
        } else if viewModel.engagement != nil {
            content
        } else {
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

    @ViewBuilder
    private var content: some View {
        if let currentWorkout = viewModel.currentWorkout {
            heroWorkoutCard(currentWorkout)
        } else {
            restDayState
        }
        upNextSection
        nudgeSection
        bodyweightSection
    }

    // MARK: - Hero workout card

    private func heroWorkoutCard(_ currentWorkout: ConsumerProgramSummaries.CurrentWorkout) -> some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.Ascend.onPrimary.opacity(0.08))
                .frame(width: 170, height: 170)
                .offset(x: 60, y: -60)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.space3) {
                Text("Today's workout")
                    .ascendDataLabel()
                    .foregroundStyle(Color.Ascend.onPrimary.opacity(0.7))
                Text(currentWorkout.workout.name)
                    .ascendType(.title2)
                    .foregroundStyle(Color.Ascend.onPrimary)
                Text(ConsumerProgramSummaries.heroMetaLine(workout: currentWorkout.workout, weekIndex: currentWorkout.week.index))
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.onPrimary.opacity(0.85))
                AscendButton("Start workout", variant: .onColor, systemImage: "play.fill") {
                    showingWorkoutPlayer = true
                }
                .padding(.top, Spacing.space1)
            }
            .padding(Spacing.space5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous).fill(Color.Ascend.primary))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .padding(.horizontal, Spacing.space4)
    }

    // MARK: - Rest day

    /// Shown when the client's assigned program has nothing scheduled for
    /// today: a deliberate rest week (the current program week's workout
    /// list is empty) reframed as programmed recovery, not an apology — see
    /// docs/design/handoff/HANDOFF_README.md §06 "Empty — warm, one action".
    /// A client with no program assigned at all still sees the original "No
    /// workout assigned yet" prompt below.
    @ViewBuilder
    private var restDayState: some View {
        if let programTitle = viewModel.programTitle {
            VStack(alignment: .leading, spacing: Spacing.space4) {
                Card {
                    EmptyState(
                        systemImage: "moon",
                        title: "Rest day",
                        message: "\(programTitle) has today marked as recovery — no workout on the schedule. Log your bodyweight if you'd like to keep your chart current.",
                        actionTitle: "Log bodyweight",
                        action: { showingLogBodyweight = true }
                    )
                }
                .padding(.horizontal, Spacing.space4)

                if let summary = viewModel.weeklySessionSummary {
                    weeklyProgressCard(summary)
                }
            }
        } else {
            Card {
                EmptyState(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "No workout assigned yet",
                    message: "Your coach hasn't assigned a program yet — check back soon."
                )
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func weeklyProgressCard(_ summary: ConsumerProgramSummaries.WeeklySessionSummary) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("This week · \(summary.completed) of \(summary.total) sessions")
                    .ascendType(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Ascend.textPrimary)
                ProgressView(value: Double(summary.completed), total: Double(max(summary.total, 1)))
                    .tint(Color.Ascend.primary)
                Text("On track")
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.success)
            }
        }
        .padding(.horizontal, Spacing.space4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Up next

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Up next")
            Card {
                if let nextSession = viewModel.nextSession {
                    ListRow(
                        title: viewModel.coachName,
                        subtitle: "Session · \(TodaySummaries.relativeDayLabel(for: nextSession.scheduledAt, now: clock()))",
                        leading: { Avatar(name: viewModel.coachName, size: .md) },
                        trailing: {
                            Text(nextSession.scheduledAt.formatted(.dateTime.hour().minute()))
                                .ascendType(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(Color.Ascend.textPrimary)
                        }
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
                    HStack(alignment: .top, spacing: Spacing.space3) {
                        Avatar(name: viewModel.coachName, size: .md)
                        VStack(alignment: .leading, spacing: Spacing.space1) {
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.space2) {
                                Text(viewModel.coachName)
                                    .ascendType(.headline)
                                    .foregroundStyle(Color.Ascend.textPrimary)
                                Text(nudge.sentAt.formatted(.relative(presentation: .named)))
                                    .ascendType(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.Ascend.textTertiary)
                            }
                            Text(nudge.body)
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textPrimary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal, Spacing.space4)
            }
        }
    }

    // MARK: - Bodyweight

    @ViewBuilder
    private var bodyweightSection: some View {
        if !viewModel.bodyweightPoints.isEmpty {
            Card {
                ProgressChart(
                    title: "Bodyweight",
                    unit: viewModel.bodyweightUnit,
                    points: viewModel.bodyweightPoints,
                    lineColor: Color.Ascend.primary,
                    lowerIsBetter: true
                )
            }
            .padding(.horizontal, Spacing.space4)
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

#Preview("ConsumerHomeView - Rest day - Light") {
    ConsumerHomeRestDayPreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerHomeView - Rest day - Dark") {
    ConsumerHomeRestDayPreview()
        .preferredColorScheme(.dark)
}

#Preview("ConsumerHomeView - Loading - Light") {
    ConsumerHomeLoadingPreview()
        .preferredColorScheme(.light)
}

#Preview("ConsumerHomeView - Loading - Dark") {
    ConsumerHomeLoadingPreview()
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
