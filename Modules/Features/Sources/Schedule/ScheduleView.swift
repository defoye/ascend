import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's day/week schedule: every session across every engagement,
/// with lifecycle actions (complete/cancel/no-show) on `.scheduled` rows, a
/// "book session" sheet, and an "availability" editor (see
/// docs/design/DESIGN_SPEC.md).
///
/// Expects to be pushed onto an existing `NavigationStack` (e.g. from
/// `TodayView`'s "See all" action) rather than owning one itself.
public struct ScheduleView: View {
    @State var viewModel: ScheduleViewModel
    @State var showingBookSession = false
    @State var showingAvailability = false
    let backend: any Backend
    let professionalID: Identifier<Person>
    let clock: @Sendable () -> Date
    let reminders: any SessionReminderScheduling

    public init(
        viewModel: ScheduleViewModel,
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        reminders: any SessionReminderScheduling = LiveSessionReminderScheduler()
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
        self.reminders = reminders
    }

    public var body: some View {
        content
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBookSession = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Book session")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button { showingAvailability = true } label: {
                        Image(systemName: "clock.badge")
                    }
                    .accessibilityLabel("Edit availability")
                }
            }
            .sheet(isPresented: $showingBookSession) {
                BookSessionView(
                    viewModel: BookSessionViewModel(
                        backend: backend,
                        professionalID: professionalID,
                        clock: clock,
                        reminders: reminders
                    ),
                    onSaved: { Task { await viewModel.load() } }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingAvailability) {
                AvailabilityEditorView(viewModel: AvailabilityViewModel(backend: backend, professionalID: professionalID))
                    .presentationDetents([.medium, .large])
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            navigationBar
            if let message = viewModel.actionErrorMessage {
                Text(message)
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.danger)
                    .padding(.horizontal, Spacing.space4)
                    .padding(.top, Spacing.space2)
            }
            if let loadErrorMessage = viewModel.loadErrorMessage {
                ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                    .padding(.horizontal, Spacing.space4)
                    .padding(.top, Spacing.space2)
            }
            if viewModel.groupedDisplayedSessions.isEmpty && !viewModel.isLoading {
                EmptyState(
                    systemImage: "calendar",
                    title: "No sessions",
                    message: emptyMessage,
                    actionTitle: "Book a session",
                    action: { showingBookSession = true }
                )
                .frame(maxHeight: .infinity)
                .background(Color.Ascend.background)
            } else {
                sessionsList
            }
        }
        .background(Color.Ascend.background)
    }

    private var emptyMessage: String {
        viewModel.viewMode == .day
            ? "No sessions scheduled for this day."
            : "No sessions scheduled for this week."
    }
}

#Preview("ScheduleView Day - Light") {
    SchedulePreview(mode: .day)
        .preferredColorScheme(.light)
}

#Preview("ScheduleView Day - Dark") {
    SchedulePreview(mode: .day)
        .preferredColorScheme(.dark)
}

#Preview("ScheduleView Week - Light") {
    SchedulePreview(mode: .week)
        .preferredColorScheme(.light)
}

#Preview("ScheduleView Week - Dark") {
    SchedulePreview(mode: .week)
        .preferredColorScheme(.dark)
}

private struct SchedulePreview: View {
    let mode: ScheduleViewMode

    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        let viewModel = ScheduleViewModel(
            backend: backend,
            professionalID: professionalID,
            clock: { Date() },
            reminders: MockSessionReminderScheduler()
        )
        viewModel.viewMode = mode
        return NavigationStack {
            ScheduleView(
                viewModel: viewModel,
                backend: backend,
                professionalID: professionalID,
                reminders: MockSessionReminderScheduler()
            )
        }
    }
}
