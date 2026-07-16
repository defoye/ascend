import DesignSystem
import Domain
import SwiftUI
import UIKit

/// A `.sheet`-presented flow for starting a new coaching relationship via
/// invite code: the coach creates a code, shares it out-of-band, and the
/// client claims it after signing up (see `InviteClientViewModel`,
/// `ClaimInviteViewModel`).
public struct InviteClientView: View {
    @State private var viewModel: InviteClientViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: InviteClientViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    createSection
                    if let createdInvite = viewModel.createdInvite {
                        shareSection(createdInvite)
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .ascendType(.footnote)
                            .foregroundStyle(Color.Ascend.danger)
                            .padding(.horizontal, Spacing.space4)
                    }
                    pendingSection
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationTitle("Invite client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
        }
    }

    // MARK: - Create

    private var createSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("New invite")
            Card {
                VStack(alignment: .leading, spacing: Spacing.space4) {
                    AscendTextField(
                        label: "Client name (optional)",
                        placeholder: "Jordan Lee",
                        text: $viewModel.suggestedClientName
                    )
                    AscendButton("Create invite", isLoading: viewModel.isSaving) {
                        Task { await viewModel.createInvite() }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    // MARK: - Share

    private func shareSection(_ invite: EngagementInvite) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Share this code")
            Card {
                VStack(spacing: Spacing.space4) {
                    Text(invite.code)
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Ascend.textPrimary)
                        .accessibilityLabel("Invite code \(invite.code.map(String.init).joined(separator: " "))")

                    HStack(spacing: Spacing.space3) {
                        ShareLink(item: shareText(for: invite)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.string = invite.code
                        } label: {
                            Label("Copy code", systemImage: "doc.on.doc")
                        }
                    }
                    .ascendType(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Ascend.primary)
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func shareText(for invite: EngagementInvite) -> String {
        "Join me on Ascend! Download the app, sign up, and enter invite code \(invite.code)."
    }

    // MARK: - Pending

    @ViewBuilder
    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Waiting to join")
            Card {
                if viewModel.pendingInvites.isEmpty {
                    EmptyState(
                        systemImage: "envelope.badge.person.crop",
                        title: "No pending invites",
                        message: "Create an invite above to start a new coaching relationship."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.pendingInvites.enumerated()), id: \.element.id) { index, invite in
                            if index > 0 {
                                Divider()
                            }
                            pendingRow(invite)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.space4)
        }
    }

    private func pendingRow(_ invite: EngagementInvite) -> some View {
        ListRow(
            title: invite.code,
            subtitle: pendingSubtitle(for: invite),
            leading: {
                Image(systemName: "envelope.badge.person.crop")
                    .foregroundStyle(Color.Ascend.primary)
            },
            trailing: {
                Button {
                    Task { await viewModel.revoke(invite) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.Ascend.textTertiary)
                }
                .accessibilityLabel("Revoke invite")
            }
        )
    }

    private func pendingSubtitle(for invite: EngagementInvite) -> String {
        let name = invite.suggestedClientName ?? "No name given"
        let created = invite.createdAt.formatted(.relative(presentation: .named))
        return "\(name) · Created \(created)"
    }
}

#Preview("InviteClientView - Light") {
    InviteClientPreview()
        .preferredColorScheme(.light)
}

#Preview("InviteClientView - Dark") {
    InviteClientPreview()
        .preferredColorScheme(.dark)
}

private struct InviteClientPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        InviteClientView(viewModel: InviteClientViewModel(backend: PreviewBackend(professionalID: professionalID), professionalID: professionalID))
    }
}
