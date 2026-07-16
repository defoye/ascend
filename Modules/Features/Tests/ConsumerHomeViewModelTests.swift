import DataInterfaces
import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ConsumerHomeViewModel against seeded data")
@MainActor
struct ConsumerHomeViewModelTests {
    @Test("loads Morgan Chen's engagement, current workout, next session, and latest coach message")
    func loadsCoherentDashboardForSeededClient() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })

        let viewModel = ConsumerHomeViewModel(backend: backend, clientID: morganChen.id, clock: { InMemoryStore.referenceDate })
        await viewModel.load()

        #expect(viewModel.loadErrorMessage == nil)
        #expect(viewModel.engagement != nil)
        #expect(viewModel.clientName == "Morgan Chen")
        #expect(viewModel.coachName == "Jordan Ellis")
        #expect(viewModel.programTitle == "Fat Loss Kickstart")
        #expect(viewModel.currentWorkout != nil)

        let nextSession = try #require(viewModel.nextSession)
        #expect(nextSession.status == .scheduled)
        #expect(nextSession.scheduledAt >= InMemoryStore.referenceDate)

        let nudge = try #require(viewModel.coachNudge)
        #expect(nudge.authorID == viewModel.engagement?.professionalID)

        // Morgan Chen has four seeded bodyweight entries and no sessions
        // falling in `referenceDate`'s calendar week (see
        // `MockData+Activity.swift`), so the chart has real data while the
        // weekly mini progress card is honestly absent rather than faked.
        #expect(viewModel.bodyweightPoints.count == 4)
        #expect(viewModel.bodyweightUnit == "lb")
        #expect(viewModel.bodyweightPoints.map(\.value) == [210, 205, 200, 196])
        #expect(viewModel.weeklySessionSummary == nil)
    }

    @Test("a client with no engagements sees a nil engagement and no error, not a crash")
    func clientWithNoEngagementSeesEmptyState() async {
        let backend = InMemoryStore.seeded()
        let viewModel = ConsumerHomeViewModel(backend: backend, clientID: Identifier(), clock: { InMemoryStore.referenceDate })
        await viewModel.load()

        #expect(viewModel.engagement == nil)
        #expect(viewModel.currentWorkout == nil)
        #expect(viewModel.nextSession == nil)
        #expect(viewModel.loadErrorMessage == nil)
        #expect(viewModel.bodyweightPoints.isEmpty)
        #expect(viewModel.weeklySessionSummary == nil)
    }

    @Test("a failing message fetch surfaces loadErrorMessage instead of hanging")
    func failingMessagesSurfacesLoadError() async throws {
        let seeded = InMemoryStore.seeded()
        let people = try await seeded.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })

        let backend = ConsumerMessagesOverrideBackend(base: seeded, messages: ConsumerAlwaysFailingMessageRepository())
        let viewModel = ConsumerHomeViewModel(backend: backend, clientID: morganChen.id, clock: { InMemoryStore.referenceDate })

        await viewModel.load()

        #expect(viewModel.loadErrorMessage != nil)
    }
}

private struct ConsumerAlwaysFailingMessageRepository: MessageRepository {
    struct OfflineError: Error {}
    func fetchMessages(forEngagement engagementID: Identifier<Engagement>) async throws -> [Message] { throw OfflineError() }
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> { AsyncStream { $0.finish() } }
    func send(_ message: Message) async throws {}
}

/// A `Backend` decorator that swaps in a replacement `MessageRepository`
/// while forwarding every other repository to `base` (mirrors
/// `TodayView.swift`'s `HangingEngagementsBackend`).
private struct ConsumerMessagesOverrideBackend: Backend {
    let base: any Backend
    let messages: any MessageRepository

    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { base.professionals }
    var engagements: any EngagementRepository { base.engagements }
    var programs: any ProgramRepository { base.programs }
    var sessions: any SessionRepository { base.sessions }
    var progress: any ProgressRepository { base.progress }
    var progressPhotos: any ProgressPhotoRepository { base.progressPhotos }
    var payments: any PaymentRepository { base.payments }
    var paymentGateway: any PaymentGateway { base.paymentGateway }
    var outcomes: any OutcomeRepository { base.outcomes }
    var notes: any NotesRepository { base.notes }
    var availability: any AvailabilityRepository { base.availability }
    var invites: any InviteRepository { base.invites }
    var auth: any AuthGateway { base.auth }
    var analytics: any AnalyticsTracking { base.analytics }
}
