import SwiftUI

/// A `surface`-filled, elevated container with `lg` corner radius and 16pt
/// padding (see docs/design/DESIGN_SPEC.md §3 "Cards"). Elevation is
/// resolved automatically per color scheme: a soft shadow in light mode, a
/// `border` stroke in dark mode — never both.
public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.space4)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color.Ascend.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .ascendElevation(.e1, cornerRadius: Radius.lg)
    }
}

#Preview("Card - Light") {
    CardPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Card - Dark") {
    CardPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct CardPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.space4) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.space2) {
                        Text("This week")
                            .ascendType(.title3)
                            .foregroundStyle(Color.Ascend.textPrimary)
                        Text("4 sessions completed, 1 upcoming.")
                            .ascendType(.subheadline)
                            .foregroundStyle(Color.Ascend.textSecondary)
                    }
                }
            }
            .padding(Spacing.space4)
        }
        .background(Color.Ascend.background)
    }
}
