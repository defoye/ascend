import Accessibility
import Charts
import SwiftUI

/// A line + soft area-fill chart of a metric over time: 2.5px stroke,
/// end-point dot, tabular value + directional delta, sparse mono axis
/// labels, minimal/no gridlines (see docs/design/DESIGN_SPEC.md §3 "Progress
/// chart"). Data is honest: the axis is never hidden or truncated in a
/// misleading way.
///
/// Copy stays within Invariant 2 (docs/PRODUCT.md): the value line and
/// accessibility summary describe a **measured journey** over time, never a
/// caused outcome.
public struct ProgressChart: View {
    private let title: String
    private let unit: String
    private let points: [ProgressPoint]
    private let targetValue: Double?
    private let lineColor: Color
    /// When `true`, a decrease is shown as the positive (`success`) delta —
    /// e.g. weight-loss journeys, where "down is good" (spec §3).
    private let lowerIsBetter: Bool

    public init(
        title: String,
        unit: String,
        points: [ProgressPoint],
        targetValue: Double? = nil,
        lineColor: Color = Color.Ascend.primary,
        lowerIsBetter: Bool = false
    ) {
        self.title = title
        self.unit = unit
        self.points = points
        self.targetValue = targetValue
        self.lineColor = lineColor
        self.lowerIsBetter = lowerIsBetter
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space3) {
            header
            chart
                .frame(height: 200)
        }
        .accessibilityElement(children: .contain)
        .accessibilityChartDescriptor(self)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(title)
                .ascendType(.headline)
                .foregroundStyle(Color.Ascend.textPrimary)
            if let last = points.last {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.space2) {
                    Text(formattedValue(last.value))
                        .ascendType(.statMedium)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    Text(unit)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textSecondary)
                    if let deltaText {
                        Text(deltaText)
                            .ascendType(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(deltaColor)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value(unit, point.value))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", point.date), y: .value(unit, point.value))
                    .foregroundStyle(areaGradient)
                    .interpolationMethod(.catmullRom)
            }
            if let last = points.last {
                PointMark(x: .value("Date", last.date), y: .value(unit, last.value))
                    .foregroundStyle(lineColor)
                    .symbolSize(50)
            }
            if let targetValue {
                RuleMark(y: .value("Target", targetValue))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.Ascend.verified)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Target")
                            .ascendType(.caption2)
                            .foregroundStyle(Color.Ascend.verified)
                    }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: sparseAxisDates) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                            .ascendDataLabel()
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
            }
        }
    }

    /// Only the first and last data points get an axis label — the spec's
    /// "sparse mono axis labels (Wk 1 / Now)".
    private var sparseAxisDates: [Date] {
        [points.first?.date, points.last?.date].compactMap { $0 }
    }

    private func axisLabel(for date: Date) -> String {
        if let last = points.last, Calendar.current.isDate(date, inSameDayAs: last.date) {
            return "Now"
        }
        return formattedDate(date)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [Color.Ascend.chartFill, .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var deltaText: String? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        let change = last.value - first.value
        let arrow = change >= 0 ? "▲" : "▼"
        return "\(arrow) \(formattedValue(abs(change))) \(unit)"
    }

    private var deltaColor: Color {
        guard let first = points.first, let last = points.last, points.count > 1 else {
            return Color.Ascend.textSecondary
        }
        let increased = last.value >= first.value
        let isImprovement = lowerIsBetter ? !increased : increased
        return isImprovement ? Color.Ascend.success : Color.Ascend.danger
    }

    nonisolated private func formattedValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    nonisolated private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// `AXChartDescriptorRepresentable.makeChartDescriptor()` is a `nonisolated`
// protocol requirement, but `ProgressChart` (a `View`) is implicitly
// MainActor-isolated. The conformance is pure data transformation over the
// struct's own `Sendable` `let` properties, so it's safe to opt the whole
// conformance out of actor isolation rather than isolate it to the main
// actor (which the `nonisolated` requirement wouldn't satisfy anyway).
nonisolated extension ProgressChart: AXChartDescriptorRepresentable {
    public func makeChartDescriptor() -> AXChartDescriptor {
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let range = low == high ? low...(high + 1) : low...high

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Date",
            categoryOrder: points.map { formattedDate($0.date) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: unit,
            range: range,
            gridlinePositions: []
        ) { [self] value in "\(formattedValue(value)) \(unit)" }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: true,
            dataPoints: points.map { point in
                AXDataPoint(x: formattedDate(point.date), y: point.value)
            }
        )

        return AXChartDescriptor(
            title: title,
            summary: accessibilitySummary,
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else {
            return "\(title). No data logged yet."
        }
        let change = last.value - first.value
        let direction = change >= 0 ? "increased" : "decreased"
        return "\(title). Measured journey from \(formattedValue(first.value)) \(unit) on "
            + "\(formattedDate(first.date)) to \(formattedValue(last.value)) \(unit) on "
            + "\(formattedDate(last.date)), \(direction) by \(formattedValue(abs(change))) \(unit)."
    }
}

#Preview("ProgressChart - Light") {
    ProgressChartPreview()
        .preferredColorScheme(.light)
}

#Preview("ProgressChart - Dark") {
    ProgressChartPreview()
        .preferredColorScheme(.dark)
}

private struct ProgressChartPreview: View {
    private static let calendar = Calendar.current
    private static let samplePoints: [ProgressPoint] = Array((0..<8).map { index in
        let date = calendar.date(byAdding: .weekOfYear, value: -index, to: .now) ?? .now
        let value = 182.0 - Double(index) * 1.6
        return ProgressPoint(date: date, value: value)
    }.reversed())

    var body: some View {
        VStack(spacing: Spacing.space4) {
            Card {
                ProgressChart(
                    title: "Body weight",
                    unit: "lb",
                    points: Self.samplePoints,
                    targetValue: 168,
                    lineColor: Color.Ascend.success,
                    lowerIsBetter: true
                )
            }
            Card {
                ProgressChart(
                    title: "Bench press 1RM",
                    unit: "lb",
                    points: Self.samplePoints.map { ProgressPoint(date: $0.date, value: 200 - $0.value + 20) }
                )
            }
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
