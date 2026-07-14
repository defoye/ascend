import DesignSystem
import SwiftUI

/// An in-app privacy-policy stub, reachable from `SettingsView`. Mirrors
/// `docs/PRIVACY_POLICY.md` (the bundled canonical copy) and
/// `App/Resources/PrivacyInfo.xcprivacy` (the machine-readable manifest App
/// Store review checks against) — all three should stay in sync when the
/// product's actual data collection changes.
public struct PrivacyPolicyView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.space5) {
                section(
                    title: "What we collect",
                    body: """
                    Your name, the progress metrics you or your coach log (e.g. \
                    bodyweight, strength numbers), progress photos you choose to \
                    share, and messages between you and your coach.
                    """
                )
                section(
                    title: "Progress metrics and photos are sensitive",
                    body: """
                    Progress metrics and progress photos are treated as sensitive \
                    health-adjacent data. Photos are never visible to your coach \
                    until you explicitly grant photo-sharing consent for that \
                    engagement, and you can revoke it at any time — revoking \
                    immediately stops your coach from seeing any of your photos. \
                    Whether your progress counts toward a "verified outcome" on \
                    your coach's profile is a separate consent you control from \
                    the "Share progress" screen, also revocable at any time.
                    """
                )
                section(
                    title: "What we don't do",
                    body: """
                    We don't sell your data. We don't track you across other \
                    companies' apps or websites. We don't show ads. Card details \
                    are handled directly by our payment processor and never pass \
                    through or get stored on our servers.
                    """
                )
                section(
                    title: "Your controls",
                    body: """
                    You can review and change your sharing consent at any time \
                    from Settings and the "Share progress" screen, and you can \
                    permanently delete your account and its data from Settings.
                    """
                )
                section(
                    title: "Questions",
                    body: "Contact your coach or the account holder for this workspace with any privacy questions."
                )
            }
            .padding(Spacing.space4)
        }
        .background(Color.Ascend.background)
        .navigationTitle("Privacy Policy")
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.space2) {
            Text(title)
                .ascendType(.headline)
                .foregroundStyle(Color.Ascend.textPrimary)
            Text(body)
                .ascendType(.subheadline)
                .foregroundStyle(Color.Ascend.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("PrivacyPolicyView - Light") {
    NavigationStack { PrivacyPolicyView() }
        .preferredColorScheme(.light)
}

#Preview("PrivacyPolicyView - Dark") {
    NavigationStack { PrivacyPolicyView() }
        .preferredColorScheme(.dark)
}
