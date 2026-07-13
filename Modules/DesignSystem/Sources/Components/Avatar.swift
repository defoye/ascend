import SwiftUI

/// Sizing for `Avatar`.
public enum AvatarSize: Sendable {
    case sm
    case md
    case lg
    case xl

    var diameter: CGFloat {
        switch self {
        case .sm: 28
        case .md: 40
        case .lg: 56
        case .xl: 88
        }
    }
}

/// A circular avatar: renders an image when provided, otherwise initials on a
/// muted tinted fill derived from the name (see docs/design/DESIGN_SPEC.md §3
/// "Avatars").
///
/// Initials are sized proportionally to the circle rather than via a text
/// style — like Contacts/Messages, avatar glyphs are graphical elements that
/// intentionally don't reflow with Dynamic Type; the person's name is always
/// exposed to assistive technology via `accessibilityLabel`.
public struct Avatar: View {
    private static let tintPalette: [Color] = [
        .Ascend.primary,
        .Ascend.verified,
        .Ascend.success,
        .Ascend.warning,
        .Ascend.danger
    ]

    private let name: String
    private let image: Image?
    private let size: AvatarSize
    private let showsVerifiedBadge: Bool

    public init(name: String, image: Image? = nil, size: AvatarSize = .md, showsVerifiedBadge: Bool = false) {
        self.name = name
        self.image = image
        self.size = size
        self.showsVerifiedBadge = showsVerifiedBadge
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            base
                .frame(width: size.diameter, height: size.diameter)
                .clipShape(Circle())
            if showsVerifiedBadge {
                VerifiedBadge(style: .circular)
            }
        }
        .accessibilityLabel(showsVerifiedBadge ? "\(name), verified" : name)
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private var base: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(tint.opacity(0.16))
                Text(initials)
                    .font(.system(size: size.diameter * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }
        }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var tint: Color {
        let index = Self.stableHash(name) % Self.tintPalette.count
        return Self.tintPalette[index]
    }

    /// A hash stable across process launches (unlike `String.hashValue`,
    /// which is randomized per run) so the same name always maps to the same
    /// tint.
    private static func stableHash(_ string: String) -> Int {
        var hash = 5381
        for scalar in string.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }
}

/// A stacked group of avatars overlapping by −10pt with a 2px `surface`
/// ring, collapsing overflow into a trailing "+N" tile (see
/// docs/design/DESIGN_SPEC.md §3 "Avatars").
public struct AvatarStack: View {
    private let names: [String]
    private let maxVisible: Int
    private let size: AvatarSize

    public init(names: [String], maxVisible: Int = 3, size: AvatarSize = .md) {
        self.names = names
        self.maxVisible = maxVisible
        self.size = size
    }

    public var body: some View {
        let visible = Array(names.prefix(maxVisible))
        let overflow = names.count - visible.count

        HStack(spacing: -10) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, name in
                Avatar(name: name, size: size)
                    .overlay(Circle().strokeBorder(Color.Ascend.surface, lineWidth: 2))
            }
            if overflow > 0 {
                ZStack {
                    Circle().fill(Color.Ascend.surfaceSecondary)
                    Text("+\(overflow)")
                        .font(.system(size: size.diameter * 0.32, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
                .frame(width: size.diameter, height: size.diameter)
                .overlay(Circle().strokeBorder(Color.Ascend.surface, lineWidth: 2))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(groupLabel)
    }

    private var groupLabel: String {
        guard names.count > maxVisible else {
            return names.joined(separator: ", ")
        }
        let shown = names.prefix(maxVisible).joined(separator: ", ")
        return "\(shown), and \(names.count - maxVisible) more"
    }
}

#Preview("Avatar - Light") {
    AvatarPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("Avatar - Dark") {
    AvatarPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct AvatarPreviewGallery: View {
    var body: some View {
        VStack(spacing: Spacing.space4) {
            HStack(spacing: Spacing.space3) {
                Avatar(name: "Jordan Lee", size: .sm)
                Avatar(name: "Priya Nair", size: .md)
                Avatar(name: "Sam Okafor", size: .lg, showsVerifiedBadge: true)
                Avatar(name: "Ana Costa", size: .xl)
            }
            AvatarStack(names: ["Jordan Lee", "Priya Nair", "Sam Okafor", "Ana Costa", "Kai Chen"])
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
