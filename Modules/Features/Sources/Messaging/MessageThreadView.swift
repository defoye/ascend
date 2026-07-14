import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// A single engagement's live chat thread: bubbles trailing/`primary`-filled
/// for the signed-in coach, leading/`surfaceSecondary` for the client, a
/// "load earlier" affordance once older messages exist beyond the visible
/// window, and a compose bar that sends through
/// `MessageThreadViewModel.send()` (see docs/design/DESIGN_SPEC.md §3, §5).
public struct MessageThreadView: View {
    @State private var viewModel: MessageThreadViewModel

    public init(viewModel: MessageThreadViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            threadScrollView
            Divider()
            composeBar
        }
        .background(Color.Ascend.background)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    // MARK: - Thread

    private var threadScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.space3) {
                    if viewModel.hasEarlierMessages {
                        loadEarlierButton
                    }
                    ForEach(viewModel.visibleMessages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(Spacing.space4)
            }
            .onChange(of: viewModel.messages.last?.id) { _, _ in
                scrollToNewest(proxy: proxy)
            }
            .task {
                scrollToNewest(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToNewest(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastID = viewModel.visibleMessages.last?.id else { return }
        if animated {
            withAnimation {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private var loadEarlierButton: some View {
        AscendButton("Load earlier messages", variant: .text, size: .compact) {
            viewModel.loadEarlier()
        }
        .frame(maxWidth: .infinity)
        .accessibilityHint("Shows older messages in this conversation")
    }

    private func messageBubble(_ message: Message) -> some View {
        let isFromMe = viewModel.isFromMe(message)
        return VStack(alignment: isFromMe ? .trailing : .leading, spacing: Spacing.space1) {
            Text(message.body)
                .ascendType(.body)
                .foregroundStyle(isFromMe ? Color.Ascend.onPrimary : Color.Ascend.textPrimary)
                .padding(.horizontal, Spacing.space3)
                .padding(.vertical, Spacing.space2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(isFromMe ? Color.Ascend.primary : Color.Ascend.surfaceSecondary)
                )
            Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                .ascendType(.caption2)
                .foregroundStyle(Color.Ascend.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: isFromMe ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bubbleAccessibilityLabel(message, isFromMe: isFromMe))
    }

    private func bubbleAccessibilityLabel(_ message: Message, isFromMe: Bool) -> String {
        let sender = isFromMe ? "You" : "Client"
        let time = message.sentAt.formatted(date: .omitted, time: .shortened)
        return "\(sender), \(message.body), sent at \(time)"
    }

    // MARK: - Compose

    private var composeBar: some View {
        HStack(alignment: .bottom, spacing: Spacing.space2) {
            AscendTextField(placeholder: "Message", text: $viewModel.draft)
            sendButton
        }
        .padding(Spacing.space4)
        .background(Color.Ascend.surface)
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.send() }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.title)
                .foregroundStyle(canSend ? Color.Ascend.primary : Color.Ascend.textTertiary)
        }
        .disabled(!canSend)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("Send message")
    }

    private var canSend: Bool {
        !viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview("MessageThreadView - Light") {
    MessageThreadPreview()
        .preferredColorScheme(.light)
}

#Preview("MessageThreadView - Dark") {
    MessageThreadPreview()
        .preferredColorScheme(.dark)
}

private struct MessageThreadPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        NavigationStack {
            MessageThreadView(
                viewModel: MessageThreadViewModel(
                    backend: backend,
                    engagementID: backend.engagementAID,
                    selfID: professionalID
                )
            )
        }
    }
}
