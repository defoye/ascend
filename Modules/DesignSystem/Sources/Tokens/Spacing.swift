import CoreGraphics

/// Spacing tokens on a 4pt base grid (see docs/design/DESIGN_SPEC.md §2.4).
public enum Spacing {
    /// 4pt — icon ↔ label, chip inner gaps.
    public static let space1: CGFloat = 4
    /// 8pt — tight stacks, inline gaps.
    public static let space2: CGFloat = 8
    /// 12pt — list-row internal gap.
    public static let space3: CGFloat = 12
    /// 16pt — default card padding, screen gutters.
    public static let space4: CGFloat = 16
    /// 20pt — section gaps.
    public static let space5: CGFloat = 20
    /// 24pt — between major blocks.
    public static let space6: CGFloat = 24
    /// 32pt — screen top padding.
    public static let space8: CGFloat = 32
    /// 40pt — large separations.
    public static let space10: CGFloat = 40
    /// 48pt — hero spacing.
    public static let space12: CGFloat = 48
}
