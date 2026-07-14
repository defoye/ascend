import Domain
import Foundation

/// A conversation row: an engagement's client identity joined with its
/// latest message preview/timestamp and unread count, ready for
/// `ConversationsListView`.
public struct ConversationSummary: Sendable, Identifiable, Equatable {
    public let engagementID: Identifier<Engagement>
    public let clientName: String
    public let lastMessagePreview: String?
    public let lastMessageAt: Date?
    public let unreadCount: Int

    public init(
        engagementID: Identifier<Engagement>,
        clientName: String,
        lastMessagePreview: String?,
        lastMessageAt: Date?,
        unreadCount: Int
    ) {
        self.engagementID = engagementID
        self.clientName = clientName
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
    }

    public var id: Identifier<Engagement> { engagementID }
}

/// Pure, directly-testable logic behind the coach "Messages" conversation
/// list — kept free of any backend/view-model dependency (mirrors
/// `ClientsSummaries`; see docs/TESTING.md).
public enum ConversationSummaries {
    /// The number of `messages` that count as unread for `selfID`: authored
    /// by someone else, sent after `lastReadAt`. Messages authored by
    /// `selfID` are NEVER unread. A `nil` `lastReadAt` means every
    /// counterparty message is unread (the thread has never been opened).
    public static func unreadCount(
        messages: [Message],
        selfID: Identifier<Person>,
        lastReadAt: Date?
    ) -> Int {
        messages.filter { message in
            guard message.authorID != selfID else { return false }
            guard let lastReadAt else { return true }
            return message.sentAt > lastReadAt
        }.count
    }

    /// Builds a single conversation summary for one engagement from its
    /// ordered messages, resolved client name, and this professional's
    /// `lastReadAt` watermark for that engagement. The preview/timestamp
    /// come from the newest message by `sentAt`, regardless of author.
    public static func summary(
        engagementID: Identifier<Engagement>,
        clientName: String,
        messages: [Message],
        selfID: Identifier<Person>,
        lastReadAt: Date?
    ) -> ConversationSummary {
        let lastMessage = messages.max { $0.sentAt < $1.sentAt }
        return ConversationSummary(
            engagementID: engagementID,
            clientName: clientName,
            lastMessagePreview: lastMessage?.body,
            lastMessageAt: lastMessage?.sentAt,
            unreadCount: unreadCount(messages: messages, selfID: selfID, lastReadAt: lastReadAt)
        )
    }

    /// The default conversation ordering: most recently active first;
    /// conversations with no messages yet sort last, alphabetical by client
    /// name within that group.
    public static func sorted(_ summaries: [ConversationSummary]) -> [ConversationSummary] {
        summaries.sorted { lhs, rhs in
            switch (lhs.lastMessageAt, rhs.lastMessageAt) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (nil, nil):
                return lhs.clientName.localizedCaseInsensitiveCompare(rhs.clientName) == .orderedAscending
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }
}
