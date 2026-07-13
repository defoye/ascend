import SwiftUI

/// An uppercase-tracked section title with an optional trailing plain-text
/// action, e.g. "See all" (see docs/design/DESIGN_SPEC.md §5).
public struct SectionHeader: View {
    private let title: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title.uppercased())
                .ascendType(.footnote)
                .foregroundStyle(Color.Ascend.textSecondary)
                .tracking(0.6)
            Spacer(minLength: Spacing.space2)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .ascendType(.footnote)
                        .foregroundStyle(Color.Ascend.primary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(.horizontal, Spacing.space4)
        .padding(.bottom, Spacing.space2)
    }
}

#Preview("SectionHeader - Light") {
    SectionHeaderPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("SectionHeader - Dark") {
    SectionHeaderPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct SectionHeaderPreviewGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Upcoming sessions", actionTitle: "See all", action: {})
            SectionHeader("Clients")
        }
        .background(Color.Ascend.background)
    }
}
