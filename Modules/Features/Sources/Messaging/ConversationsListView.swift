import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's "Messages" tab: one row per engagement with its last message
/// preview, relative timestamp, and unread indicator, pushing into
/// `MessageThreadView` on tap (see docs/design/DESIGN_SPEC.md §3 list rows).
///
/// Expects to be hosted inside a `NavigationStack` supplied by its parent
/// (`CoachRootView`) rather than owning one itself — mirrors
/// `ClientsListView`.
public struct ConversationsListView: View {
    @State private var viewModel: ConversationsListViewModel
    @State private var selectedEngagementID: Identifier<Engagement>?
    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(viewModel: ConversationsListViewModel, backend: any Backend, professionalID: Identifier<Person>) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
    }

    public var body: some View {
        content
            .navigationTitle("Messages")
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
            .navigationDestination(item: $selectedEngagementID) { engagementID in
                MessageThreadView(
                    viewModel: MessageThreadViewModel(
                        backend: backend,
                        engagementID: engagementID,
                        selfID: professionalID
                    )
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.conversations.isEmpty && !viewModel.isLoading {
            VStack(spacing: Spacing.space4) {
                if let loadErrorMessage = viewModel.loadErrorMessage {
                    ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                        .padding(.horizontal, Spacing.space4)
                }
                EmptyState(
                    systemImage: "bubble.left",
                    title: "No conversations yet",
                    message: "Message threads with your clients will show up here."
                )
            }
            .frame(maxHeight: .infinity)
            .background(Color.Ascend.background)
        } else {
            ScrollView {
                VStack(spacing: Spacing.space4) {
                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                            .padding(.horizontal, Spacing.space4)
                    }
                    Card {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.conversations.enumerated()), id: \.element.id) { index, conversation in
                                if index > 0 {
                                    Divider()
                                }
                                conversationRow(conversation)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.space4)
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
        }
    }

    private func conversationRow(_ conversation: ConversationSummary) -> some View {
        Button {
            viewModel.markRead(conversation.engagementID)
            selectedEngagementID = conversation.engagementID
        } label: {
            ListRow(
                title: conversation.clientName,
                subtitle: conversation.lastMessagePreview ?? "No messages yet",
                leading: { Avatar(name: conversation.clientName, size: .md) },
                trailing: { trailingAccessory(for: conversation) }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: conversation))
    }

    private func trailingAccessory(for conversation: ConversationSummary) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.space1) {
            if let lastMessageAt = conversation.lastMessageAt {
                Text(lastMessageAt.formatted(.relative(presentation: .named)))
                    .ascendType(.footnote)
                    .foregroundStyle(Color.Ascend.textTertiary)
            }
            if conversation.unreadCount > 0 {
                unreadBadge(conversation.unreadCount)
            }
        }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .ascendType(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Color.Ascend.onPrimary)
            .padding(.horizontal, Spacing.space2)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(Color.Ascend.primary))
            .accessibilityHidden(true)
    }

    private func accessibilityLabel(for conversation: ConversationSummary) -> String {
        var label = conversation.clientName
        if let preview = conversation.lastMessagePreview {
            label += ", \(preview)"
        }
        if conversation.unreadCount > 0 {
            label += ", \(conversation.unreadCount) unread"
        }
        return label
    }
}

#Preview("ConversationsListView - Light") {
    ConversationsListPreview()
        .preferredColorScheme(.light)
}

#Preview("ConversationsListView - Dark") {
    ConversationsListPreview()
        .preferredColorScheme(.dark)
}

private struct ConversationsListPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            ConversationsListView(
                viewModel: ConversationsListViewModel(backend: backend, professionalID: professionalID),
                backend: backend,
                professionalID: professionalID
            )
        }
    }
}
