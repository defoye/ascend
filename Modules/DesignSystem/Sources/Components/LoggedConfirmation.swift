import SwiftUI

/// The "logged" success microinteraction (see
/// docs/design/handoff/HANDOFF_README.md §06 "Shared state kit" — 'Success
/// "logged": spring 0.5s (check 0.7→1.08→1), one light success haptic on
/// commit, factual delta copy (state number + change, no praise
/// adjectives), success-green used for the delta only — teal stays the
/// brand.'). A self-contained primitive: Phase 4 wires this into the Workout
/// Player; this phase only builds and previews it.
///
/// `value` is the resulting state (e.g. "185 lb × 5") and `delta` is the
/// factual change (e.g. "+5 lb vs. last week") — callers own the copy;
/// this view never editorializes.
public struct LoggedConfirmation: View {
    private let value: String
    private let delta: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkScale: CGFloat = 0.7
    @State private var isVisible = false

    public init(value: String, delta: String) {
        self.value = value
        self.delta = delta
    }

    public var body: some View {
        HStack(spacing: Spacing.space2) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.Ascend.primary)
                .scaleEffect(checkScale)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .ascendType(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Ascend.textPrimary)
                Text(delta)
                    .ascendType(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.Ascend.success)
            }
        }
        .padding(.horizontal, Spacing.space3)
        .frame(minHeight: 30)
        .background(Capsule().fill(Color.Ascend.surfaceSecondary))
        .opacity(isVisible ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value), \(delta)")
        .onAppear(perform: commit)
    }

    /// Fires the one commit haptic and plays the pop (or, under Reduce
    /// Motion, a plain cross-fade).
    private func commit() {
        AscendHaptics.success()
        guard !reduceMotion else {
            isVisible = true
            checkScale = 1
            return
        }
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = true
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            checkScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                checkScale = 1
            }
        }
    }
}

#Preview("LoggedConfirmation - Light") {
    LoggedConfirmationPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("LoggedConfirmation - Dark") {
    LoggedConfirmationPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct LoggedConfirmationPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            LoggedConfirmation(value: "Set 2 logged · 185 lb × 5", delta: "+5 lb vs. last week")
            LoggedConfirmation(value: "181 lb", delta: "−15 lb")
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
