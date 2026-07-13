import SwiftUI

/// Centered zero-data placeholder: icon in a tinted circle, title, message,
/// and an optional primary action (see docs/design/DESIGN_SPEC.md §5).
public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Spacing.space4) {
            ZStack {
                Circle()
                    .fill(Color.Ascend.surfaceSecondary)
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.Ascend.primary)
            }
            .accessibilityHidden(true)

            VStack(spacing: Spacing.space2) {
                Text(title)
                    .ascendType(.title3)
                    .foregroundStyle(Color.Ascend.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                AscendButton(actionTitle, size: .compact, action: action)
            }
        }
        .padding(Spacing.space6)
        .frame(maxWidth: .infinity)
    }
}

#Preview("EmptyState - Light") {
    EmptyStatePreview()
        .preferredColorScheme(.light)
}

#Preview("EmptyState - Dark") {
    EmptyStatePreview()
        .preferredColorScheme(.dark)
}

private struct EmptyStatePreview: View {
    var body: some View {
        EmptyState(
            systemImage: "figure.strengthtraining.traditional",
            title: "No clients yet",
            message: "When you start an engagement with a client, it will show up here.",
            actionTitle: "Add a client",
            action: {}
        )
        .background(Color.Ascend.background)
    }
}
