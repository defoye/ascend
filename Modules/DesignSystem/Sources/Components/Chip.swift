import SwiftUI

/// The three chip/tag archetypes from docs/design/DESIGN_SPEC.md §3
/// "Chips / tags".
public enum ChipStyle: Sendable, Equatable {
    /// Selected = `primary` fill; idle = `border` outline + `textSecondary`.
    case filter(isSelected: Bool)
    /// `surfaceSecondary` fill + a 7px category dot.
    case goalTag(dotColor: Color)
    /// Outline + coloured dot + label.
    case status(StatusTone)
}

/// Coloring for `.status` chips: Active = `success`, Pending = `warning`,
/// Paused = `textSecondary`.
public enum StatusTone: String, Sendable, CaseIterable {
    case active = "Active"
    case pending = "Pending"
    case paused = "Paused"

    var color: Color {
        switch self {
        case .active: Color.Ascend.success
        case .pending: Color.Ascend.warning
        case .paused: Color.Ascend.textSecondary
        }
    }
}

/// A 28–30pt pill used as a filter chip, goal tag, or status pill. Purely
/// presentational; wrap in a `Button` (via `action`) when the chip is
/// interactive — `Chip` extends its own hit target to 44pt when an action is
/// supplied, independent of the smaller visible pill.
public struct Chip: View {
    private let text: String
    private let style: ChipStyle
    private let action: (() -> Void)?

    public init(_ text: String, style: ChipStyle = .filter(isSelected: false), action: (() -> Void)? = nil) {
        self.text = text
        self.style = style
        self.action = action
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { pill }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            } else {
                pill
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(accessibilityTraits)
    }

    @ViewBuilder
    private var pill: some View {
        switch style {
        case let .filter(isSelected):
            HStack(spacing: Spacing.space1) {
                Text(text)
            }
            .ascendType(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(isSelected ? Color.Ascend.onPrimary : Color.Ascend.textSecondary)
            .padding(.horizontal, Spacing.space3)
            .frame(height: 30)
            .background(Capsule().fill(isSelected ? Color.Ascend.primary : Color.clear))
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : Color.Ascend.border, lineWidth: 1)
            )

        case let .goalTag(dotColor):
            HStack(spacing: Spacing.space1) {
                Circle().fill(dotColor).frame(width: 7, height: 7)
                Text(text)
            }
            .ascendType(.footnote)
            .foregroundStyle(Color.Ascend.textPrimary)
            .padding(.horizontal, Spacing.space3)
            .frame(height: 30)
            .background(Capsule().fill(Color.Ascend.surfaceSecondary))

        case let .status(tone):
            HStack(spacing: Spacing.space1) {
                Circle().fill(tone.color).frame(width: 7, height: 7)
                Text(text)
            }
            .ascendType(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(tone.color)
            .padding(.horizontal, Spacing.space3)
            .frame(height: 28)
            .background(
                Capsule().strokeBorder(tone.color.opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var accessibilityTraits: AccessibilityTraits {
        if case let .filter(isSelected) = style, isSelected {
            return [.isSelected]
        }
        return []
    }
}

#Preview("Chip - Light") {
    ChipPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Chip - Dark") {
    ChipPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ChipPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space4) {
            HStack(spacing: Spacing.space2) {
                Chip("All clients", style: .filter(isSelected: true))
                Chip("Strength", style: .filter(isSelected: false))
                Chip("Online", style: .filter(isSelected: false))
            }
            HStack(spacing: Spacing.space2) {
                Chip("Weight loss", style: .goalTag(dotColor: Color.Ascend.primary))
                Chip("Mobility", style: .goalTag(dotColor: Color.Ascend.warning))
            }
            HStack(spacing: Spacing.space2) {
                Chip(StatusTone.active.rawValue, style: .status(.active))
                Chip(StatusTone.pending.rawValue, style: .status(.pending))
                Chip(StatusTone.paused.rawValue, style: .status(.paused))
            }
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
