import SwiftUI

/// An inline, dismiss-free error banner: a warning glyph, a message, and an
/// optional "Try again" action (see docs/design/DESIGN_SPEC.md §5). Used
/// wherever a view model's `loadErrorMessage` needs to be surfaced instead
/// of silently leaving the user looking at a generic (and misleading) empty
/// state — see docs/ROADMAP.md Prompt 16's error/empty/loading-state pass.
///
/// Deliberately non-modal and non-blocking: it renders inline above whatever
/// content did load, so a transient refresh failure never hides data the
/// user already has on screen.
public struct ErrorBanner: View {
    private let message: String
    private let retryTitle: String
    private let retry: (() -> Void)?

    public init(message: String, retryTitle: String = "Try again", retry: (() -> Void)? = nil) {
        self.message = message
        self.retryTitle = retryTitle
        self.retry = retry
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.space3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.Ascend.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.space2) {
                Text(message)
                    .ascendType(.subheadline)
                    .foregroundStyle(Color.Ascend.textPrimary)
                if let retry {
                    Button(retryTitle, action: retry)
                        .ascendType(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Ascend.primary)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
            Spacer(minLength: Spacing.space2)
        }
        .padding(Spacing.space4)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.Ascend.danger.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(Color.Ascend.danger.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview("ErrorBanner - Light") {
    ErrorBannerPreviewGallery()
        .preferredColorScheme(.light)
}

#Preview("ErrorBanner - Dark") {
    ErrorBannerPreviewGallery()
        .preferredColorScheme(.dark)
}

private struct ErrorBannerPreviewGallery: View {
    var body: some View {
        VStack(spacing: Spacing.space4) {
            ErrorBanner(message: "Couldn't load your clients. Pull to refresh to try again.")
            ErrorBanner(message: "Couldn't load your dashboard.", retry: {})
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.background)
    }
}
