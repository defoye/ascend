import CoreGraphics

/// Corner-radius tokens (see docs/design/DESIGN_SPEC.md §2.5). `pill` is
/// represented as a large-but-finite constant here for callers that need a
/// `CGFloat` (SwiftUI clamps corner radii to half the shortest side, so this
/// always resolves to a full capsule); prefer the `Capsule()` shape directly
/// for pill-shaped components.
public enum Radius {
    /// 8pt — chips, small tiles, inputs' inner.
    public static let sm: CGFloat = 8
    /// 12pt — buttons, inputs, segmented controls.
    public static let md: CGFloat = 12
    /// 16pt — cards.
    public static let lg: CGFloat = 16
    /// 22pt — hero cards, bottom sheets.
    public static let xl: CGFloat = 22
    /// 999 — pills, tab-bar highlights, avatars.
    public static let pill: CGFloat = 999
}
