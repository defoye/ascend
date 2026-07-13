import SwiftUI

/// Elevation levels (see docs/design/DESIGN_SPEC.md §2.6). Shadows are subtle
/// and used sparingly; in dark mode elevation is carried by `surface`
/// lightness + `border`, not shadow — so dark mode always renders a 1px
/// `border` stroke instead of the light-mode shadow pair.
public enum Elevation: Sendable {
    /// Flat, on-surface — no shadow, 1px `border` only.
    case e0
    /// Cards, raised rows.
    case e1
    /// Sheets, popovers, floating CTAs.
    case e2
}

private struct AscendElevationModifier: ViewModifier {
    let level: Elevation
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    /// Fixed shadow tint from the spec's `rgba(16,24,40,…)` values — shadows
    /// use this constant navy regardless of theme (they only ever render in
    /// light mode; dark mode substitutes a border stroke).
    private var shadowBase: Color { Color(red: 16 / 255, green: 24 / 255, blue: 40 / 255) }

    func body(content: Content) -> some View {
        Group {
            switch level {
            case .e0:
                content.overlay(borderStroke)
            case .e1:
                if colorScheme == .dark {
                    content.overlay(borderStroke)
                } else {
                    content
                        .shadow(color: shadowBase.opacity(0.06), radius: 1, x: 0, y: 1)
                        .shadow(color: shadowBase.opacity(0.08), radius: 1.5, x: 0, y: 1)
                }
            case .e2:
                if colorScheme == .dark {
                    content.overlay(borderStroke)
                } else {
                    content
                        .shadow(color: shadowBase.opacity(0.09), radius: 8, x: 0, y: 6)
                        .shadow(color: shadowBase.opacity(0.16), radius: 17, x: 0, y: 16)
                }
            }
        }
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.Ascend.border, lineWidth: 1)
    }
}

extension View {
    /// Resolves the correct elevation treatment (shadow vs. border) for the
    /// current color scheme. `cornerRadius` should match the shape the
    /// elevated surface is drawn with (defaults to `Radius.lg`, the card
    /// default).
    public func ascendElevation(_ level: Elevation, cornerRadius: CGFloat = Radius.lg) -> some View {
        modifier(AscendElevationModifier(level: level, cornerRadius: cornerRadius))
    }
}
