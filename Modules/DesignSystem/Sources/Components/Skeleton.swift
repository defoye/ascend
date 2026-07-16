import SwiftUI

/// Loading-state building blocks (see docs/design/handoff/HANDOFF_README.md
/// §06 "Shared state kit" — "Loading — skeleton not spinner: matches final
/// layout box-for-box, neutral fills (never brand color), shimmer 1.4s").
/// Compose `SkeletonBlock`/`SkeletonText` inside `SkeletonCard` to mirror a
/// real screen's layout box-for-box. Fills use only the neutral `skeleton` /
/// `skeleton2` tokens — never the brand teal.
///
/// A single shimmering rounded rect — the base primitive every other
/// skeleton shape is built from.
public struct SkeletonBlock: View {
    private let width: CGFloat?
    private let height: CGFloat
    private let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = Radius.sm) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.Ascend.skeleton)
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    ShimmerSweep()
                }
            }
            .clipShape(shape)
            .accessibilityHidden(true)
    }
}

/// A skeleton line of text — a `SkeletonBlock` sized like a row of body
/// copy, for mirroring titles, labels and paragraph lines.
public struct SkeletonText: View {
    private let width: CGFloat
    private let height: CGFloat

    public init(width: CGFloat, height: CGFloat = 12) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        SkeletonBlock(width: width, height: height, cornerRadius: 4)
    }
}

/// A `Card`-shaped skeleton container (same fill, radius and elevation as
/// `Card`) hosting an arbitrary stack of skeleton primitives, so a loading
/// state can mirror a real card's layout box-for-box.
public struct SkeletonCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(Color.Ascend.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .ascendElevation(.e1, cornerRadius: Radius.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
    }
}

/// The `ascShim` sweep: a `skeleton2` highlight band moving left→right over
/// 1.4s, linear, repeating. Only rendered when Reduce Motion is off — callers
/// (`SkeletonBlock`) skip it entirely under Reduce Motion, leaving a static
/// `skeleton` fill.
private struct ShimmerSweep: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, Color.Ascend.skeleton2, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.6)
            .offset(x: phase * geometry.size.width * 1.6 - geometry.size.width * 0.3)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
    }
}

#Preview("Skeleton - Light") {
    SkeletonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Skeleton - Dark") {
    SkeletonPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SkeletonPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.space4) {
                SkeletonCard {
                    VStack(alignment: .leading, spacing: Spacing.space3) {
                        HStack(spacing: Spacing.space3) {
                            SkeletonBlock(width: 40, height: 40, cornerRadius: 20)
                            VStack(alignment: .leading, spacing: Spacing.space2) {
                                SkeletonText(width: 140)
                                SkeletonText(width: 90, height: 10)
                            }
                        }
                        SkeletonBlock(height: 12, cornerRadius: 4)
                        SkeletonText(width: 220)
                    }
                }
                SkeletonCard {
                    SkeletonBlock(height: 120)
                }
            }
            .padding(Spacing.space4)
        }
        .background(Color.Ascend.background)
    }
}
