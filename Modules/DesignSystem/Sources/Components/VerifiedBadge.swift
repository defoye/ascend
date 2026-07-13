import SwiftUI

/// The three lock-ups from docs/design/DESIGN_SPEC.md §3 "Verified badge".
public enum VerifiedBadgeStyle: Sendable {
    /// Filled `verified` pill, checkmark + "Verified journey" — the primary
    /// trust surface. Always pair with substantiation copy nearby.
    case filled
    /// Outline check + "Verified" — a compact inline lock-up, e.g. next to a
    /// name.
    case compact
    /// A 22–24px circular check with a `surface` ring, for avatar overlays
    /// and other lock-ups. Icon-only; hidden from VoiceOver since the
    /// context it decorates (e.g. `Avatar`) already announces the person.
    case circular
}

/// Ascend's trust mark: reserved for verified-outcome surfaces only. Per
/// Invariant 2 (docs/PRODUCT.md), the spoken copy always describes a
/// **verified journey** or verification status, never a caused result — and
/// the badge never animates on its own (spec §4: "trust marks stay still and
/// factual").
public struct VerifiedBadge: View {
    private let style: VerifiedBadgeStyle

    public init(style: VerifiedBadgeStyle = .filled) {
        self.style = style
    }

    public var body: some View {
        switch style {
        case .filled: filledPill
        case .compact: compactInline
        case .circular: circularCheck
        }
    }

    private var filledPill: some View {
        HStack(spacing: Spacing.space1) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
            Text("Verified journey")
                .ascendType(.footnote)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.Ascend.onVerified)
        .padding(.horizontal, Spacing.space3)
        .frame(height: 30)
        .background(Capsule().fill(Color.Ascend.verified))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verified journey")
    }

    private var compactInline: some View {
        HStack(spacing: Spacing.space1) {
            Image(systemName: "checkmark.seal")
            Text("Verified")
                .ascendType(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Color.Ascend.verified)
        .padding(.horizontal, Spacing.space2)
        .frame(height: 24)
        .overlay(Capsule().strokeBorder(Color.Ascend.verified, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verified")
    }

    private var circularCheck: some View {
        ZStack {
            Circle().fill(Color.Ascend.verified)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.Ascend.onVerified)
        }
        .frame(width: 22, height: 22)
        .overlay(Circle().strokeBorder(Color.Ascend.surface, lineWidth: 3))
        .accessibilityHidden(true)
    }
}

#Preview("VerifiedBadge - Light") {
    VerifiedBadgePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("VerifiedBadge - Dark") {
    VerifiedBadgePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct VerifiedBadgePreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            VerifiedBadge(style: .filled)
            VerifiedBadge(style: .compact)
            VerifiedBadge(style: .circular)
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
