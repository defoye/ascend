import SwiftUI

/// Visual treatment for `AscendButton` (see docs/design/DESIGN_SPEC.md §3
/// "Buttons").
public enum AscendButtonVariant: Sendable {
    /// `primary` fill, `onPrimary` label — the default call to action.
    case primary
    /// Tonal: `secondary` fill, `textSecondary` label.
    case secondary
    /// Outline for reversible destructive actions: `danger` border + label,
    /// no fill.
    case destructiveOutline
    /// Filled for confirm-in-sheet destructive actions: `danger` fill, white
    /// label.
    case destructiveFilled
    /// No fill, `primary` label — nav bar actions, inline actions.
    case text
}

/// Sizing for `AscendButton`.
public enum AscendButtonSize: Sendable {
    /// 50pt tall, full-width by default.
    case large
    /// 44pt tall (the minimum accessible hit target).
    case compact
    /// 32pt tall, capsule-shaped — filter-adjacent inline actions. Rendered
    /// with an invisible 44pt hit-target so it stays accessible even though
    /// the visible pill is smaller.
    case pill

    var height: CGFloat {
        switch self {
        case .large: 50
        case .compact: 44
        case .pill: 32
        }
    }
}

/// Ascend's action button: primary / secondary(tonal) / destructive(outline
/// or filled) / text, plus a small-pill size. Supports normal, pressed,
/// disabled, and loading states, and an optional leading SF Symbol (see
/// docs/design/DESIGN_SPEC.md §3).
public struct AscendButton: View {
    private let title: String
    private let variant: AscendButtonVariant
    private let size: AscendButtonSize
    private let systemImage: String?
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    public init(
        _ title: String,
        variant: AscendButtonVariant = .primary,
        size: AscendButtonSize = .large,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: size == .large ? .infinity : nil)
                .frame(height: size.height)
                .padding(.horizontal, size == .pill ? Spacing.space3 : Spacing.space4)
        }
        .background(background)
        .foregroundStyle(foreground)
        .overlay(border)
        .clipShape(shape)
        .opacity(isEnabled ? (isPressed ? 0.9 : 1) : 0.38)
        .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.9), value: isPressed)
        .disabled(!isEnabled || isLoading)
        .buttonStyle(PressReportingButtonStyle(isPressed: $isPressed))
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var label: some View {
        if isLoading {
            ProgressView()
                .tint(foreground)
                .accessibilityHidden(true)
        } else {
            HStack(spacing: Spacing.space2) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .ascendType(size == .pill ? .footnote : .headline)
            .fontWeight(.semibold)
        }
    }

    private var accessibilityLabel: String {
        isLoading ? "\(title), loading" : title
    }

    private var shape: AnyShape {
        size == .pill ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            Color.Ascend.primary.opacity(isPressed ? 0.85 : 1)
        case .secondary:
            Color.Ascend.secondary
        case .destructiveOutline, .text:
            Color.clear
        case .destructiveFilled:
            Color.Ascend.danger.opacity(isPressed ? 0.85 : 1)
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary: Color.Ascend.onPrimary
        case .secondary: Color.Ascend.textSecondary
        case .destructiveOutline: Color.Ascend.danger
        case .destructiveFilled: .white
        case .text: Color.Ascend.primary
        }
    }

    @ViewBuilder
    private var border: some View {
        if variant == .destructiveOutline {
            shape.stroke(Color.Ascend.danger, lineWidth: 1.5)
        }
    }
}

/// A `ButtonStyle` that reports its pressed state outward so `AscendButton`
/// can drive its own scale/opacity animation while keeping the tap target's
/// default SwiftUI press handling.
private struct PressReportingButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

#Preview("AscendButton - Light") {
    AscendButtonPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("AscendButton - Dark") {
    AscendButtonPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct AscendButtonPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.space4) {
                AscendButton("Log session", systemImage: "checkmark.circle.fill") {}
                AscendButton("Edit profile", variant: .secondary) {}
                AscendButton("Remove client", variant: .destructiveOutline) {}
                AscendButton("Delete account", variant: .destructiveFilled) {}
                AscendButton("See all", variant: .text) {}
                AscendButton("Compact", size: .compact) {}
                AscendButton("Small pill", size: .pill) {}
                AscendButton("Disabled", isEnabled: false) {}
                AscendButton("Loading", isLoading: true) {}
            }
            .padding(Spacing.space4)
        }
        .background(Color.Ascend.background)
    }
}
