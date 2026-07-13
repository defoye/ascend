import SwiftUI

/// A standard row: leading icon/avatar, title + optional subtitle, and an
/// optional trailing accessory. Tappable rows render a chevron and collapse
/// into a single accessibility element (see docs/design/DESIGN_SPEC.md §5).
public struct ListRow<Leading: View, Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let leading: Leading
    private let trailing: Trailing
    private let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        if let action {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        } else {
            rowContent
                .accessibilityElement(children: .combine)
        }
    }

    private var rowContent: some View {
        HStack(spacing: Spacing.space3) {
            leading
            VStack(alignment: .leading, spacing: Spacing.space1) {
                Text(title)
                    .ascendType(.headline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .ascendType(.subheadline)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
            }
            Spacer(minLength: Spacing.space2)
            trailing
            if action != nil {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.Ascend.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.space3)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

extension ListRow where Leading == EmptyView, Trailing == EmptyView {
    public init(title: String, subtitle: String? = nil, action: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, action: action, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

#Preview("ListRow - Light") {
    ListRowPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ListRow - Dark") {
    ListRowPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ListRowPreviewGallery: View {
    var body: some View {
        VStack(spacing: 0) {
            ListRow(
                title: "Jordan Lee",
                subtitle: "Strength coaching · Weekly",
                action: {},
                leading: { Avatar(name: "Jordan Lee", size: .md) },
                trailing: {
                    Text("Active")
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.textSecondary)
                }
            )
            Divider()
            ListRow(
                title: "Next session",
                subtitle: "Tomorrow, 9:00 AM",
                leading: {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.Ascend.primary)
                },
                trailing: { EmptyView() }
            )
        }
        .background(Color.Ascend.surface)
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
