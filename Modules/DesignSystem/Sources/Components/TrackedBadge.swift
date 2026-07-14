import SwiftUI

/// A "Tracked results" badge — the `PaymentsMode.free` counterpart to
/// `VerifiedBadge`, deliberately built from different iconography, wording,
/// and tone (a muted trend-line glyph in `Color.Ascend.textSecondary`
/// instead of `VerifiedBadge`'s bold seal glyph in `Color.Ascend.verified`)
/// so a coach or client can never mistake a Tracked journey for a
/// `Domain.VerifiedOutcome`-backed Verified one (see docs/BUILD_STATUS.md
/// "Rollout strategy — free first, monetize later", Option B). The muted
/// tone is deliberate: Tracked is honestly a step below Verified, and
/// turning payments on is what upgrades it. Like `VerifiedBadge`, it never
/// animates on its own — trust marks stay still and factual
/// (docs/design/DESIGN_SPEC.md §4).
public struct TrackedBadge: View {
    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.space1) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            Text("Tracked")
                .ascendType(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.Ascend.textSecondary)
        .padding(.horizontal, Spacing.space2)
        .frame(height: 24)
        .overlay(Capsule().strokeBorder(Color.Ascend.textTertiary, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tracked")
    }
}

#Preview("TrackedBadge - Light") {
    TrackedBadgePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("TrackedBadge - Dark") {
    TrackedBadgePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct TrackedBadgePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            TrackedBadge()
            VerifiedBadge(style: .compact)
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
