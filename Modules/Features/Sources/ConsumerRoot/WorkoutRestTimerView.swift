import DesignSystem
import SwiftUI

/// The rest timer's ring: a circular progress ring (94pt radius, 12pt
/// stroke, primary sweep over a `surfaceSecondary` track) counting down from
/// `restDuration`, center "REST / m:ss / of m:ss" in large tabular figures,
/// −15s and Skip controls, and the "Set N logged · …" confirmation chip
/// (see docs/design/handoff/HANDOFF_README.md §05 "Rest timer"). Purely
/// local view state driven by the bound `restEndDate` — nothing about rest
/// duration is persisted. Split out of `WorkoutPlayerView.swift` purely to
/// stay under SwiftLint's `file_length` (mirrors `ClientDetailView`'s
/// same-type-extension split).
struct RestTimerView: View {
    let restDuration: TimeInterval
    @Binding var restEndDate: Date?
    let setNumber: Int
    let confirmationValue: String
    let confirmationDelta: String
    let nextSetNumber: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var timeFontSize: CGFloat = 54

    var body: some View {
        if let restEndDate {
            VStack(spacing: Spacing.space5) {
                LoggedConfirmation(value: "Set \(setNumber) logged · \(confirmationValue)", delta: confirmationDelta)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, restEndDate.timeIntervalSince(context.date))
                    ring(remaining: remaining)
                        .onChange(of: remaining) { _, newValue in
                            guard newValue == 0 else { return }
                            AscendHaptics.success()
                            self.restEndDate = nil
                        }
                }
                controls(currentEndDate: restEndDate)
                AscendButton("Next: Set \(nextSetNumber)", variant: .secondary) {
                    self.restEndDate = nil
                }
            }
        }
    }

    private func ring(remaining: TimeInterval) -> some View {
        let progress = restDuration > 0 ? remaining / restDuration : 0
        return ZStack {
            Circle()
                .stroke(Color.Ascend.surfaceSecondary, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.Ascend.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)
            VStack(spacing: Spacing.space1) {
                Text("Rest")
                    .ascendDataLabel()
                    .foregroundStyle(Color.Ascend.textTertiary)
                Text(ConsumerProgramSummaries.formattedDuration(remaining))
                    .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.Ascend.textPrimary)
                Text("of \(ConsumerProgramSummaries.formattedDuration(restDuration))")
                    .ascendType(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Color.Ascend.textSecondary)
            }
        }
        .frame(width: 188, height: 188)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Resting, \(Int(remaining)) seconds remaining of \(Int(restDuration))")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func controls(currentEndDate: Date) -> some View {
        HStack(spacing: Spacing.space3) {
            Button {
                restEndDate = max(Date(), currentEndDate.addingTimeInterval(-15))
            } label: {
                Label("−15s", systemImage: "gobackward.15")
            }
            .buttonStyle(RestControlButtonStyle())

            Button("Skip rest") {
                AscendHaptics.impact(.light)
                restEndDate = nil
            }
            .buttonStyle(RestControlButtonStyle(color: Color.Ascend.primary))
        }
    }
}

private struct RestControlButtonStyle: ButtonStyle {
    var color: Color = Color.Ascend.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .ascendType(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.space4)
            .frame(minWidth: 44, minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Color.Ascend.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("WorkoutPlayerView - Live rest timer - Light") {
    RestTimerPreview()
        .preferredColorScheme(.light)
}

#Preview("WorkoutPlayerView - Live rest timer - Dark") {
    RestTimerPreview()
        .preferredColorScheme(.dark)
}

/// Renders the rest timer ring directly, mid-countdown, so the "Live rest
/// timer" state is previewable without driving the full log → commit flow.
private struct RestTimerPreview: View {
    @State private var restEndDate: Date? = Date().addingTimeInterval(72)

    var body: some View {
        VStack {
            Spacer()
            RestTimerView(
                restDuration: 120,
                restEndDate: $restEndDate,
                setNumber: 2,
                confirmationValue: "185 lb × 5",
                confirmationDelta: "+5 lb vs. last logged",
                nextSetNumber: 3
            )
            Spacer()
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
