import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The journey-detail bottom sheet (docs/design/handoff/HANDOFF_README.md
/// "Interactions & Behavior": "Proof Profile journey → journey detail
/// sheet"): an anonymized metric trajectory, timeframe, measured delta, and
/// the mode-appropriate "Backed by" line. Every value comes from
/// `JourneyDetailContent`, itself derived only from a `VerifiedJourney`/
/// `TrackedJourney` — this view never names a client or claims the coach
/// caused the outcome (Invariant 2, docs/PRODUCT.md).
///
/// `VerifiedOutcome`/`TrackedJourney` retain only the first and last
/// qualifying progress measurement, not every point in between — so the
/// trajectory below is an honest two-point line (start → end), never an
/// invented intermediate series.
struct JourneyDetailSheetView: View {
    let content: JourneyDetailContent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space5) {
                    badgeRow
                    Card {
                        ProgressChart(
                            title: content.metricDisplayName,
                            unit: content.unit.shortLabel,
                            points: trajectoryPoints,
                            lineColor: Color.Ascend.primary,
                            lowerIsBetter: content.lowerIsBetter
                        )
                    }
                    timeframeCard
                    backedByCard
                }
                .padding(.horizontal, Spacing.space4)
                .padding(.vertical, Spacing.space5)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Journey detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// The trust badge — never animated (docs/design/DESIGN_SPEC.md §4).
    private var badgeRow: some View {
        HStack(spacing: Spacing.space2) {
            if content.isVerified {
                VerifiedBadge(style: .filled)
            } else {
                TrackedBadge()
            }
            Spacer(minLength: 0)
        }
    }

    private var trajectoryPoints: [ProgressPoint] {
        [
            ProgressPoint(date: content.startedAt, value: content.start.value),
            ProgressPoint(date: content.endedAt, value: content.end.value)
        ]
    }

    private var timeframeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("Timeframe")
                    .ascendDataLabel()
                    .foregroundStyle(Color.Ascend.textTertiary)
                Text(content.summaryLine)
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var backedByCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text("Backed by")
                    .ascendDataLabel()
                    .foregroundStyle(Color.Ascend.textTertiary)
                Text(content.substantiationLine)
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("JourneyDetailSheetView - Verified - Light") {
    JourneyDetailSheetView(content: .previewVerified)
        .preferredColorScheme(.light)
}

#Preview("JourneyDetailSheetView - Verified - Dark") {
    JourneyDetailSheetView(content: .previewVerified)
        .preferredColorScheme(.dark)
}

#Preview("JourneyDetailSheetView - Tracked - Light") {
    JourneyDetailSheetView(content: .previewTracked)
        .preferredColorScheme(.light)
}

#Preview("JourneyDetailSheetView - Tracked - Dark") {
    JourneyDetailSheetView(content: .previewTracked)
        .preferredColorScheme(.dark)
}

extension JourneyDetailContent {
    fileprivate static var previewVerified: JourneyDetailContent {
        JourneyDetailContent(
            id: "preview-verified",
            metricDisplayName: MetricKind.squat1RM.displayName,
            unit: .lb,
            start: MetricValue(value: 185, unit: .lb),
            end: MetricValue(value: 225, unit: .lb),
            startedAt: Date().addingTimeInterval(-28 * 86_400),
            endedAt: Date(),
            weeks: 4,
            summaryLine: ProofProfileSummaries.journeySummaryLine(
                metric: .squat1RM,
                start: MetricValue(value: 185, unit: .lb),
                end: MetricValue(value: 225, unit: .lb),
                durationDays: 28
            ),
            substantiationLine: ProofProfileCopy.substantiationLine(for: .live),
            lowerIsBetter: MetricKind.squat1RM.lowerIsGenerallyBetter,
            isVerified: true
        )
    }

    fileprivate static var previewTracked: JourneyDetailContent {
        JourneyDetailContent(
            id: "preview-tracked",
            metricDisplayName: MetricKind.bodyweight.displayName,
            unit: .lb,
            start: MetricValue(value: 210, unit: .lb),
            end: MetricValue(value: 196, unit: .lb),
            startedAt: Date().addingTimeInterval(-56 * 86_400),
            endedAt: Date(),
            weeks: 8,
            summaryLine: ProofProfileSummaries.journeySummaryLine(
                metric: .bodyweight,
                start: MetricValue(value: 210, unit: .lb),
                end: MetricValue(value: 196, unit: .lb),
                durationDays: 56
            ),
            substantiationLine: ProofProfileCopy.substantiationLine(for: .free),
            lowerIsBetter: MetricKind.bodyweight.lowerIsGenerallyBetter,
            isVerified: false
        )
    }
}
