import SwiftUI

/// A directional change shown under a `StatTile` value, e.g. "up 12 this
/// month". Color alone never carries the meaning — an arrow icon always
/// accompanies it.
public enum StatDelta: Sendable {
    case up(String)
    case down(String)

    var isUp: Bool {
        if case .up = self { true } else { false }
    }

    var text: String {
        switch self {
        case let .up(text), let .down(text): text
        }
    }
}

/// A compact metric block: uppercase-tracked label, `statMedium` value,
/// optional unit and delta. Grid-friendly (2-up/3-up) (see
/// docs/design/DESIGN_SPEC.md §5).
public struct StatTile: View {
    private let label: String
    private let value: String
    private let unit: String?
    private let delta: StatDelta?

    public init(label: String, value: String, unit: String? = nil, delta: StatDelta? = nil) {
        self.label = label
        self.value = value
        self.unit = unit
        self.delta = delta
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(label)
                .ascendDataLabel()
                .foregroundStyle(Color.Ascend.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.space1) {
                Text(value)
                    .ascendType(.statMedium)
                    .foregroundStyle(Color.Ascend.textPrimary)
                if let unit {
                    Text(unit)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
            }
            if let delta {
                HStack(spacing: Spacing.space1) {
                    Text(delta.isUp ? "▲" : "▼")
                    Text(delta.text)
                }
                .ascendType(.footnote)
                .monospacedDigit()
                .foregroundStyle(delta.isUp ? Color.Ascend.success : Color.Ascend.danger)
            }
        }
        .padding(Spacing.space4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.Ascend.surfaceSecondary)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    private var spokenLabel: String {
        var parts = [label, value]
        if let unit {
            parts.append(unit)
        }
        if let delta {
            parts.append(delta.isUp ? "up \(delta.text)" : "down \(delta.text)")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("StatTile - Light") {
    StatTilePreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("StatTile - Dark") {
    StatTilePreviewGallery()
        .preferredColorScheme(.dark)
}

private struct StatTilePreviewGallery: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.space3) {
            StatTile(label: "Sessions", value: "128", delta: .up("12 this month"))
            StatTile(label: "Retention", value: "92", unit: "%", delta: .down("2%"))
            StatTile(label: "Clients", value: "24")
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
