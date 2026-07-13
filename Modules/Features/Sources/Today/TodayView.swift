import DesignSystem
import Domain
import SwiftUI

/// The coach's daily home surface: upcoming sessions, recent client
/// activity, and a revenue snapshot (see docs/design/DESIGN_SPEC.md).
public struct TodayView: View {
    @State private var viewModel: TodayViewModel
    private let now: () -> Date

    public init(viewModel: TodayViewModel, now: @escaping () -> Date = { Date() }) {
        _viewModel = State(wrappedValue: viewModel)
        self.now = now
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    upcomingSection
                    activitySection
                    revenueSection
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Today")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Upcoming sessions

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Upcoming sessions")
            Card {
                if viewModel.upcomingSessions.isEmpty {
                    EmptyState(
                        systemImage: "calendar",
                        title: "No upcoming sessions",
                        message: "Sessions you schedule with clients will show up here."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.upcomingSessions.enumerated()), id: \.element.id) { index, upcoming in
                            if index > 0 {
                                Divider()
                            }
                            ListRow(
                                title: upcoming.clientName,
                                subtitle: sessionSubtitle(for: upcoming),
                                action: {},
                                leading: {
                                    Avatar(name: upcoming.clientName, size: .md)
                                },
                                trailing: { EmptyView() }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func sessionSubtitle(for upcoming: UpcomingSession) -> String {
        let day = TodaySummaries.relativeDayLabel(for: upcoming.scheduledAt, now: now())
        let time = upcoming.scheduledAt.formatted(.dateTime.hour().minute())
        return "\(day), \(time)"
    }

    // MARK: - Recent client activity

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Recent client activity")
            Card {
                if viewModel.recentActivity.isEmpty {
                    EmptyState(
                        systemImage: "bell",
                        title: "No activity yet",
                        message: "New progress logs and client messages will show up here."
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
                                leading: {
                                    Image(systemName: activityIcon(for: item))
                                        .foregroundStyle(Color.Ascend.primary)
                                },
                                trailing: {
                                    Text(item.occurredAt.formatted(.relative(presentation: .named)))
                                        .ascendType(.footnote)
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

    // MARK: - Revenue snapshot

    @ViewBuilder
    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Revenue snapshot")
            Card {
                if viewModel.revenueSummary.isEmpty {
                    EmptyState(
                        systemImage: "chart.bar",
                        title: "No revenue yet",
                        message: "Payments from clients over the last 30 days will show up here."
                    )
                } else {
                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, spacing: Spacing.space3) {
                        StatTile(
                            label: "Net earned",
                            value: CurrencyFormatter.dollars(fromCents: viewModel.revenueSummary.netCents)
                        )
                        StatTile(
                            label: "Gross collected",
                            value: CurrencyFormatter.dollars(fromCents: viewModel.revenueSummary.grossCents)
                        )
                        StatTile(
                            label: "Payments",
                            value: "\(viewModel.revenueSummary.count)"
                        )
                    }
                    Text("Trailing 30 days")
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textTertiary)
                        .padding(.top, Spacing.space2)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }
}

/// USD cents -> dollars formatting with tabular figures (see
/// docs/design/DESIGN_SPEC.md §2.3).
enum CurrencyFormatter {
    static func dollars(fromCents cents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let value = Double(cents) / 100
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

/// Human-readable display for a `MetricKind`/`MetricValue` pair.
enum MetricFormatter {
    static func format(_ value: MetricValue) -> String {
        let number = value.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value.value)
            : String(format: "%.1f", value.value)
        return "\(number) \(unitLabel(value.unit))"
    }

    private static func unitLabel(_ unit: MetricUnit) -> String {
        switch unit {
        case .lb: "lb"
        case .kg: "kg"
        case .inch: "in"
        case .cm: "cm"
        case .percent: "%"
        case .bpm: "bpm"
        case .seconds: "sec"
        }
    }
}

extension MetricKind {
    var displayName: String {
        switch self {
        case .bodyweight: "bodyweight"
        case .waistCircumference: "waist circumference"
        case .squat1RM: "squat 1RM"
        case .bench1RM: "bench 1RM"
        case .deadlift1RM: "deadlift 1RM"
        case .bodyFatPercentage: "body fat %"
        case .restingHeartRate: "resting heart rate"
        case .fiveKTime: "5K time"
        }
    }
}

#Preview("TodayView - Light") {
    TodayPreview()
        .preferredColorScheme(.light)
}

#Preview("TodayView - Dark") {
    TodayPreview()
        .preferredColorScheme(.dark)
}

/// A self-contained preview fixture, independent of any backend module (see
/// docs/CONVENTIONS.md — Features may not import a concrete backend). Feeds
/// the view model's observable state directly rather than loading it, since
/// `TodayViewModel` only depends on `any Backend`.
private struct TodayPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        TodayView(viewModel: TodayViewModel(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID))
    }
}
