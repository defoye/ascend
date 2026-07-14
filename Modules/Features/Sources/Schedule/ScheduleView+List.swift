import DesignSystem
import Domain
import SwiftUI

// MARK: - Session list, rows, and swipe actions
//
// Split into an extension (rather than kept in the primary declaration) purely
// to stay under SwiftLint's `type_body_length` — SwiftLint measures each
// type/extension body independently.
extension ScheduleView {
    var sessionsList: some View {
        List {
            ForEach(viewModel.groupedDisplayedSessions) { group in
                Section {
                    ForEach(group.sessions) { scheduled in
                        sessionRow(scheduled)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                swipeActions(for: scheduled)
                            }
                    }
                } header: {
                    Text(dayHeader(group.date))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.Ascend.background)
    }

    @ViewBuilder
    private func swipeActions(for scheduled: ScheduledSession) -> some View {
        if scheduled.status == .scheduled {
            Button(role: .destructive) {
                Task { await viewModel.cancel(scheduled) }
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            Button {
                Task { await viewModel.markNoShow(scheduled) }
            } label: {
                Label("No-show", systemImage: "person.fill.xmark")
            }
            .tint(Color.Ascend.warning)
            Button {
                Task { await viewModel.complete(scheduled) }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(Color.Ascend.success)
        }
    }

    private func dayHeader(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func sessionRow(_ scheduled: ScheduledSession) -> some View {
        ListRow(
            title: scheduled.clientName,
            subtitle: scheduled.scheduledAt.formatted(date: .omitted, time: .shortened),
            leading: { Avatar(name: scheduled.clientName, size: .md) },
            trailing: { statusChip(scheduled.status) }
        )
    }

    private func statusChip(_ status: SessionStatus) -> Chip {
        switch status {
        case .scheduled: Chip("Scheduled", style: .filter(isSelected: true))
        case .completed: Chip("Completed", style: .status(.active))
        case .cancelled: Chip("Cancelled", style: .filter(isSelected: false))
        case .noShow: Chip("No-show", style: .filter(isSelected: false))
        }
    }
}
