import DesignSystem
import Domain
import SwiftUI

// MARK: - Upcoming sessions, recent activity, and revenue ledger
//
// Split into an extension (rather than kept in `TodayView.swift`) purely to
// stay under SwiftLint's `file_length` / `type_body_length` — mirrors the
// same split `ClientDetailView.swift` uses for its Progress section.
extension TodayView {
    // MARK: - Upcoming sessions

    @ViewBuilder
    var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Upcoming", actionTitle: "Schedule") { showingSchedule = true }
            Card {
                if viewModel.upcomingSessions.isEmpty {
                    EmptyState(
                        systemImage: "calendar",
                        title: "No sessions today",
                        message: "Your calendar is clear. Book a session or check your week.",
                        actionTitle: "Schedule a session",
                        action: { showingSchedule = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.upcomingSessions.enumerated()), id: \.element.id) { index, upcoming in
                            if index > 0 {
                                Divider()
                            }
                            ListRow(
                                title: upcoming.clientName,
                                subtitle: TodaySummaries.relativeDayLabel(for: upcoming.scheduledAt, now: now()),
                                action: { todayDestination = .client(engagementID: upcoming.session.engagementID) },
                                leading: {
                                    Avatar(name: upcoming.clientName, size: .md)
                                },
                                trailing: {
                                    Text(upcoming.scheduledAt.formatted(.dateTime.hour().minute()))
                                        .ascendType(.subheadline)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .foregroundStyle(Color.Ascend.textPrimary)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Recent activity

    @ViewBuilder
    var activitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Recent activity")
            Card {
                if viewModel.recentActivity.isEmpty {
                    EmptyState(
                        systemImage: "checkmark",
                        title: "No recent activity",
                        message: "Client logs and messages will appear here."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentActivity.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider()
                            }
                            ListRow(
                                title: item.clientName,
                                subtitle: activitySubtitle(for: item),
                                action: { todayDestination = activityDestination(for: item) },
                                leading: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                            .fill(Color.Ascend.surfaceSecondary)
                                            .frame(width: 34, height: 34)
                                        Image(systemName: activityIcon(for: item))
                                            .foregroundStyle(Color.Ascend.primary)
                                    }
                                },
                                trailing: {
                                    Text(item.occurredAt.formatted(.relative(presentation: .named)))
                                        .ascendType(.footnote)
                                        .monospacedDigit()
                                        .foregroundStyle(Color.Ascend.textTertiary)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func activityIcon(for item: ActivityItem) -> String {
        switch item.kind {
        case .progress: "chart.line.uptrend.xyaxis"
        case .message: "bubble.left"
        }
    }

    private func activitySubtitle(for item: ActivityItem) -> String {
        switch item.kind {
        case let .progress(metric, value):
            "Logged \(metric.displayName): \(MetricFormatter.format(value))"
        case let .message(preview):
            preview
        }
    }

    /// A progress log opens the client's detail screen (where progress
    /// lives); a client message opens that engagement's message thread.
    private func activityDestination(for item: ActivityItem) -> TodayDestination {
        switch item.kind {
        case .progress:
            .client(engagementID: item.engagementID)
        case .message:
            .messageThread(engagementID: item.engagementID)
        }
    }

    // MARK: - Revenue ledger

    /// A calm ledger, not a dashboard: one big tabular net figure, then gross
    /// and the platform fee as quiet secondary rows (see
    /// docs/design/handoff/HANDOFF_README.md §01 "Revenue · last 30 days").
    @ViewBuilder
    var revenueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Revenue · last 30 days")
            Card {
                if viewModel.revenueSummary.isEmpty {
                    EmptyState(
                        systemImage: "chart.bar",
                        title: "No revenue yet",
                        message: "Payments from clients over the last 30 days will show up here."
                    )
                } else {
                    VStack(alignment: .leading, spacing: Spacing.space3) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.space2) {
                            Text(CurrencyFormatter.dollars(fromCents: viewModel.revenueSummary.netCents))
                                .ascendType(.title1)
                                .monospacedDigit()
                                .foregroundStyle(Color.Ascend.textPrimary)
                            Text("net")
                                .ascendType(.subheadline)
                                .foregroundStyle(Color.Ascend.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: Spacing.space2) {
                            ledgerRow(label: "Gross", value: CurrencyFormatter.dollars(fromCents: viewModel.revenueSummary.grossCents))
                            ledgerRow(
                                label: "Platform fee · \(platformFeePercentText)%",
                                value: "\u{2212}\(CurrencyFormatter.dollars(fromCents: platformFeeCents))"
                            )
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func ledgerRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
            Spacer(minLength: Spacing.space2)
            Text(value)
                .ascendType(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(Color.Ascend.textSecondary)
        }
    }

    private var platformFeeCents: Int {
        viewModel.revenueSummary.grossCents - viewModel.revenueSummary.netCents
    }

    private var platformFeePercentText: String {
        guard viewModel.revenueSummary.grossCents > 0 else { return "0" }
        let percent = Double(platformFeeCents) / Double(viewModel.revenueSummary.grossCents) * 100
        return String(format: "%.0f", percent)
    }
}
