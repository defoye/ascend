import SwiftUI

/// A tab-bar icon baked into a single bitmap (via `ImageRenderer`) so it can
/// carry a genuinely `Color.Ascend.primary`-colored dot regardless of the
/// tab's selected state — the quiet cross-role "something new" indicator
/// (see docs/design/DESIGN_SPEC.md §4 "Role switch" / "Calm over loud"),
/// deliberately not the system's numeric red `.badge()`.
///
/// Plain `Image(systemName:)` content passed to `.tabItem` is re-derived and
/// redrawn by the system tab bar — any sibling overlay view (e.g. a
/// `Circle` badge) placed alongside it in the same view hierarchy is
/// silently dropped. Baking the icon + dot into one bitmap first sidesteps
/// that: the system just draws the bitmap as-is.
public struct TabIconWithDot: View {
    private let systemName: String
    private let isSelected: Bool
    private let showDot: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(systemName: String, isSelected: Bool, showDot: Bool) {
        self.systemName = systemName
        self.isSelected = isSelected
        self.showDot = showDot
    }

    public var body: some View {
        Image(uiImage: renderedIcon)
            .renderingMode(.original)
    }

    @MainActor
    private var renderedIcon: UIImage {
        let tint = isSelected ? Color.Ascend.primary : Color.Ascend.textTertiary
        let content = ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(tint)
            if showDot {
                Circle()
                    .fill(Color.Ascend.primary)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 26, height: 26)
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

#Preview("TabIconWithDot - Light") {
    TabIconWithDotGallery()
        .preferredColorScheme(.light)
}

#Preview("TabIconWithDot - Dark") {
    TabIconWithDotGallery()
        .preferredColorScheme(.dark)
}

private struct TabIconWithDotGallery: View {
    var body: some View {
        HStack(spacing: Spacing.space6) {
            TabIconWithDot(systemName: "person.crop.circle", isSelected: false, showDot: false)
            TabIconWithDot(systemName: "person.crop.circle", isSelected: false, showDot: true)
            TabIconWithDot(systemName: "person.crop.circle", isSelected: true, showDot: true)
        }
        .padding(Spacing.space6)
        .background(Color.Ascend.background)
    }
}
