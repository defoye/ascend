import DataInterfaces
import Domain
import Foundation

// MARK: - Message fixtures
//
// Split into their own file (rather than kept in `PreviewBackend.swift`)
// purely to stay under SwiftLint's `file_length` — SwiftLint measures each
// file independently, mirroring the same split `PreviewBackend+Programs.swift`
// and `PreviewBackend+Payments.swift` use.
extension PreviewBackend {
    /// A coach-authored message on `engagementA` (so `ConsumerHomeView`'s "From
    /// your coach" nudge card has real data in previews) plus the existing
    /// client-authored message on `engagementB`.
    static func makeMessages(
        engagementA: Identifier<Engagement>,
        engagementB: Identifier<Engagement>,
        professionalID: Identifier<Person>,
        clientB: Identifier<Person>,
        now: Date
    ) -> [Identifier<Engagement>: [Message]] {
        [
            engagementA: [
                Message(
                    id: Identifier(),
                    engagementID: engagementA,
                    authorID: professionalID,
                    body: "Nice work on the last check-in — let's keep the streak going this week.",
                    sentAt: now.addingTimeInterval(-5 * 3_600)
                )
            ],
            engagementB: [
                Message(
                    id: Identifier(),
                    engagementID: engagementB,
                    authorID: clientB,
                    body: "New squat max today: 225!",
                    sentAt: now.addingTimeInterval(-2 * 3_600)
                )
            ]
        ]
    }
}

struct PreviewMessageRepository: MessageRepository {
    let messagesByEngagement: [Identifier<Engagement>: [Message]]
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            continuation.yield(messagesByEngagement[engagement] ?? [])
            continuation.finish()
        }
    }
    func send(_ message: Message) async throws {}
}
