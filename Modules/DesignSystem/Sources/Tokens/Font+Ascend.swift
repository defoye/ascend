import SwiftUI

/// Typography tokens (see docs/design/DESIGN_SPEC.md §2.3). Built on SwiftUI
/// text styles so Dynamic Type scales them automatically; weight/design are
/// layered on top. Never hard-code a fixed point size where a text style
/// exists.
extension Font {
    public enum Ascend {
        public static var largeTitle: Font { .system(.largeTitle, design: .default).weight(.bold) }
        public static var title1: Font { .system(.title, design: .default).weight(.bold) }
        public static var title2: Font { .system(.title2, design: .default).weight(.semibold) }
        public static var title3: Font { .system(.title3, design: .default).weight(.semibold) }
        public static var headline: Font { .system(.headline, design: .default).weight(.semibold) }
        public static var body: Font { .system(.body, design: .default) }
        public static var callout: Font { .system(.callout, design: .default) }
        public static var subheadline: Font { .system(.subheadline, design: .default) }
        public static var footnote: Font { .system(.footnote, design: .default) }
        public static var caption: Font { .system(.caption, design: .default) }
        public static var caption2: Font { .system(.caption2, design: .default) }

        /// Data / label style — SF Mono, semibold, ~11–12pt (`.caption2`
        /// text-style step). Pair with `Text.ascendDataLabel()` for the
        /// uppercase + tracking treatment the spec calls for, since those
        /// are `Text`-only modifiers rather than `Font` properties.
        public static var dataLabel: Font { .system(.caption2, design: .monospaced).weight(.semibold) }

        /// Hero stat values: rounded + monospaced digits so figures align.
        public static var statLarge: Font {
            .system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit()
        }

        /// StatTile values: rounded + monospaced digits so figures align.
        public static var statMedium: Font {
            .system(.title2, design: .rounded).weight(.semibold).monospacedDigit()
        }
    }
}

/// Identifies a typography token so `.ascendType(_)` can be used from `View`
/// call sites without repeating `Font.Ascend.*` everywhere.
public enum AscendTypeToken: Sendable {
    case largeTitle, title1, title2, title3
    case headline, body, callout, subheadline, footnote, caption, caption2
    case statLarge, statMedium

    var font: Font {
        switch self {
        case .largeTitle: Font.Ascend.largeTitle
        case .title1: Font.Ascend.title1
        case .title2: Font.Ascend.title2
        case .title3: Font.Ascend.title3
        case .headline: Font.Ascend.headline
        case .body: Font.Ascend.body
        case .callout: Font.Ascend.callout
        case .subheadline: Font.Ascend.subheadline
        case .footnote: Font.Ascend.footnote
        case .caption: Font.Ascend.caption
        case .caption2: Font.Ascend.caption2
        case .statLarge: Font.Ascend.statLarge
        case .statMedium: Font.Ascend.statMedium
        }
    }
}

extension View {
    /// Applies an Ascend typography token, including rounded/monospaced-digit
    /// treatment for stat tokens.
    ///
    /// Explicitly `nonisolated`: extension members of `View` are otherwise
    /// inferred MainActor-isolated (since `View.body` is), but this is pure
    /// styling with no actor-isolated state, and call sites like
    /// `TextFieldStyle._body(configuration:)` are themselves `nonisolated`
    /// protocol requirements — isolating this method would make it
    /// impossible to call from there.
    nonisolated public func ascendType(_ token: AscendTypeToken) -> some View {
        font(token.font)
    }
}

extension Text {
    /// The spec's "Data / label" style: SF Mono, semibold, uppercase, +0.8pt
    /// tracking, ~11–12pt (§2.3). Used for stat captions, chip labels and
    /// chart axis labels. Returns `some View` rather than `Text` because
    /// uppercasing is a `View`-level modifier (`textCase`), not a `Text`
    /// one. `nonisolated` for the same reason as `ascendType(_:)` above.
    nonisolated public func ascendDataLabel() -> some View {
        font(Font.Ascend.dataLabel)
            .tracking(0.8)
            .textCase(.uppercase)
    }
}
