#if canImport(UIKit)
import UIKit
#endif

/// Shared haptic feedback so feature call sites don't hand-roll
/// `UIFeedbackGenerator` (see docs/design/DESIGN_SPEC.md §4 "Logging
/// feedback": "a light haptic (`.success` notification / `.impact(.light)`)
/// fires. No confetti."). No-op on platforms without UIKit.
public enum AscendHaptics {
    /// Impact-feedback weight for `impact(_:)`, independent of `UIKit` so the
    /// signature compiles even where `UIImpactFeedbackGenerator` doesn't
    /// exist.
    public enum ImpactStyle: Sendable {
        case light, medium, heavy
    }

    /// The "logged" moment's haptic: one light `.success` notification.
    @MainActor
    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    /// A light impact haptic for lower-weight confirmations.
    @MainActor
    public static func impact(_ style: ImpactStyle = .light) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style.uiKitStyle).impactOccurred()
        #endif
    }
}

#if canImport(UIKit)
extension AscendHaptics.ImpactStyle {
    fileprivate var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        }
    }
}
#endif
