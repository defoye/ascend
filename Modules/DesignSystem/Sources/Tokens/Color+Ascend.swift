import SwiftUI

/// Semantic color tokens backed by `Colors.xcassets` (see
/// docs/design/DESIGN_SPEC.md §2.1–2.2). Each token has an explicit light and
/// dark appearance baked into the asset catalog, so no runtime color-scheme
/// branching is needed here.
extension Color {
    public enum Ascend {
        /// App background. Light `#F4F5F7` / Dark `#0D1013`.
        public static let background = named("Background")
        /// Cards, sheets, nav bars. Light `#FFFFFF` / Dark `#161A1F`.
        public static let surface = named("Surface")
        /// Subtle fills, segmented tracks. Light `#EEF1F4` / Dark `#1E242B`.
        public static let surfaceSecondary = named("SurfaceSecondary")
        /// Primary actions / brand. Light `#0C6B75` / Dark `#34AEBD`.
        public static let primary = named("Primary")
        /// Verified accent (= brand). Light `#0C6B75` / Dark `#3BB8C6`.
        public static let verified = named("Verified")
        /// Tonal button background. Light `#E7EBEF` / Dark `#232A32`.
        public static let secondary = named("Secondary")
        /// Positive / gains / streaks. Light `#1C8250` / Dark `#3FBE7E`.
        public static let success = named("Success")
        /// Caution / pending. Light `#8A5A00` / Dark `#D6A02E`.
        public static let warning = named("Warning")
        /// Destructive. Light `#C0362F` / Dark `#E86B63`.
        public static let danger = named("Danger")
        /// Primary text. Light `#15181E` / Dark `#F1F4F7`.
        public static let textPrimary = named("TextPrimary")
        /// Secondary text. Light `#5A6472` / Dark `#98A2AF`.
        public static let textSecondary = named("TextSecondary")
        /// Captions, placeholders. Light `#8A93A2` / Dark `#6B7480`.
        public static let textTertiary = named("TextTertiary")
        /// Separators, hairlines. Light `#E3E6EB` / Dark `#2A313A`.
        public static let border = named("Border")
        /// Text/icons on `primary`. Own dynamic asset so the label flips
        /// automatically (light = white, dark = very dark teal `#04262B`).
        public static let onPrimary = named("OnPrimary")
        /// Text/icons on `verified`. Own dynamic asset, same flip as
        /// `onPrimary` (see spec §2.2 note).
        public static let onVerified = named("OnVerified")
        /// Skeleton shimmer base fill. Light `#E7EAEF` / Dark `#1E242B`.
        public static let skeleton = named("Skeleton")
        /// Skeleton shimmer highlight sweep. Light `#EFF1F4` / Dark `#2A343D`.
        public static let skeleton2 = named("Skeleton2")

        /// Soft area-fill under the progress chart line — 14% `primary`
        /// (spec calls for 12–16%). Derived rather than a dedicated asset
        /// so it always tracks `primary` exactly, including in dark mode.
        public static var chartFill: Color { primary.opacity(0.14) }

        private static func named(_ name: String) -> Color {
            Color(name, bundle: AscendBundle.resources)
        }
    }
}
