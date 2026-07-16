import DesignSystem
import SwiftUI

/// The calm, factual "workout complete" state (see docs/design/handoff/
/// HANDOFF_README.md §05 "Workout complete"): a static teal check medallion
/// (trust marks never animate), a factual one-line summary, three
/// `StatTile`s pulled from the real session totals, and — only when
/// honestly computable — a single success card comparing today's top set to
/// the last recorded entry for that lift. No confetti, no praise
/// adjectives (Invariant-2 tone: factual, calm).
struct WorkoutCompleteView: View {
    let workoutName: String
    let totals: ConsumerProgramSummaries.SessionTotals
    let comparison: ConsumerProgramSummaries.TopSetComparison?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.space6) {
                medallion
                VStack(spacing: Spacing.space2) {
                    Text("Workout complete")
                        .ascendType(.title2)
                        .foregroundStyle(Color.Ascend.textPrimary)
                    Text(summaryText)
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                        .multilineTextAlignment(.center)
                }
                statTiles
                if let comparison {
                    comparisonCard(comparison)
                }
            }
            .padding(Spacing.space6)
            .frame(maxWidth: .infinity)
        }
        .background(Color.Ascend.background)
        .safeAreaInset(edge: .bottom) {
            AscendButton("Done", action: onDone)
                .padding(Spacing.space4)
                .background(Color.Ascend.background)
        }
    }

    /// A static (never-animated) medallion — trust marks don't animate, see
    /// docs/design/handoff/HANDOFF_README.md's motion constraints.
    private var medallion: some View {
        ZStack {
            Circle()
                .fill(Color.Ascend.primary.opacity(0.14))
                .frame(width: 88, height: 88)
            Circle()
                .fill(Color.Ascend.primary)
                .frame(width: 62, height: 62)
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.Ascend.onPrimary)
        }
        .accessibilityHidden(true)
    }

    private var summaryText: String {
        "\(workoutName) · \(totals.totalSetsLogged) set\(totals.totalSetsLogged == 1 ? "" : "s") logged in \(ConsumerProgramSummaries.formattedDuration(totals.durationSeconds))."
    }

    private var statTiles: some View {
        HStack(spacing: Spacing.space3) {
            StatTile(label: "Sets", value: "\(totals.totalSetsLogged)")
            StatTile(label: "Duration", value: ConsumerProgramSummaries.formattedDuration(totals.durationSeconds))
            StatTile(label: "lb moved", value: formattedPounds(totals.poundsMoved))
        }
    }

    private func comparisonCard(_ comparison: ConsumerProgramSummaries.TopSetComparison) -> some View {
        Card {
            HStack(spacing: Spacing.space3) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.Ascend.success)
                Text("\(comparison.exerciseName) top set \(signedDelta(comparison)) vs. last logged")
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func signedDelta(_ comparison: ConsumerProgramSummaries.TopSetComparison) -> String {
        let sign = comparison.deltaValue >= 0 ? "+" : "−"
        return "\(sign)\(formattedPounds(abs(comparison.deltaValue))) \(comparison.unit.shortLabel)"
    }

    private func formattedPounds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview("WorkoutCompleteView - Light") {
    WorkoutCompleteView(
        workoutName: "Lower Body",
        totals: ConsumerProgramSummaries.SessionTotals(totalSetsLogged: 24, durationSeconds: 47 * 60 + 12, poundsMoved: 12_850),
        comparison: ConsumerProgramSummaries.TopSetComparison(exerciseName: "Back Squat", deltaValue: 5, unit: .lb),
        onDone: {}
    )
    .preferredColorScheme(.light)
}

#Preview("WorkoutCompleteView - Dark") {
    WorkoutCompleteView(
        workoutName: "Lower Body",
        totals: ConsumerProgramSummaries.SessionTotals(totalSetsLogged: 18, durationSeconds: 32 * 60 + 5, poundsMoved: 8_400),
        comparison: nil,
        onDone: {}
    )
    .preferredColorScheme(.dark)
}
