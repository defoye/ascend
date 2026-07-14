import DesignSystem
import Domain
import SwiftUI

// MARK: - Mode picker, forward/back navigation, and availability context
//
// Split into an extension (rather than kept in the primary declaration) purely
// to stay under SwiftLint's `type_body_length` — SwiftLint measures each
// type/extension body independently.
extension ScheduleView {
    var navigationBar: some View {
        VStack(spacing: Spacing.space3) {
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(ScheduleViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.space4)

            HStack {
                Button { viewModel.goBackward() } label: {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(previousLabel)

                Spacer()

                VStack(spacing: Spacing.space1) {
                    Button("Today") { viewModel.goToToday() }
                        .ascendType(.footnote)
                        .fontWeight(.semibold)
                    Text(rangeLabel)
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }

                Spacer()

                Button { viewModel.goForward() } label: {
                    Image(systemName: "chevron.right")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(nextLabel)
            }
            .padding(.horizontal, Spacing.space4)

            if !viewModel.displayedAvailabilityWindows.isEmpty {
                availabilityContext
            }
        }
        .padding(.vertical, Spacing.space3)
        .background(Color.Ascend.surface)
    }

    private var previousLabel: String { viewModel.viewMode == .day ? "Previous day" : "Previous week" }
    private var nextLabel: String { viewModel.viewMode == .day ? "Next day" : "Next week" }

    private var rangeLabel: String {
        switch viewModel.viewMode {
        case .day:
            return viewModel.referenceDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        case .week:
            let interval = ScheduleSummaries.weekInterval(containing: viewModel.referenceDate)
            let start = interval.start.formatted(.dateTime.month(.abbreviated).day())
            let end = interval.end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day())
            return "\(start) – \(end)"
        }
    }

    private var availabilityContext: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.space2) {
                ForEach(viewModel.displayedAvailabilityWindows, id: \.id) { window in
                    Chip(availabilityLabel(for: window), style: .goalTag(dotColor: Color.Ascend.primary))
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func availabilityLabel(for window: AvailabilityWindow) -> String {
        let time = "\(ScheduleFormatting.timeString(fromMinutes: window.startMinute))–\(ScheduleFormatting.timeString(fromMinutes: window.endMinute))"
        switch viewModel.viewMode {
        case .day:
            return time
        case .week:
            let weekday = ScheduleFormatting.weekdaySymbol(window.weekday).prefix(3)
            return "\(weekday) \(time)"
        }
    }
}
