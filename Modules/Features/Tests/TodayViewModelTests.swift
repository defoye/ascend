import DataInterfaces
import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("TodayViewModel against seeded data")
@MainActor
struct TodayViewModelTests {
    @Test("upcoming sessions, revenue, and recent activity are computed correctly from seeded InMemoryStore data")
    func loadsSeededDashboard() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let now = InMemoryStore.referenceDate
        let viewModel = TodayViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live, clock: { now })
        await viewModel.load()

        // Upcoming: exactly the two seeded `.scheduled` sessions at
        // referenceDate+5 (Sam Patel) and referenceDate+7 (Morgan Chen),
        // ascending, and nothing non-scheduled or in the past leaks in.
        #expect(viewModel.upcomingSessions.count == 2)
        #expect(viewModel.upcomingSessions.allSatisfy { $0.session.status == .scheduled && $0.session.scheduledAt >= now })
        let scheduledDates = viewModel.upcomingSessions.map(\.scheduledAt)
        #expect(scheduledDates == scheduledDates.sorted())
        #expect(viewModel.upcomingSessions.map(\.clientName) == ["Sam Patel", "Morgan Chen"])

        // Revenue: only the two succeeded payments dated within the trailing
        // 30 days ending at referenceDate fall in the window (12_000 cents at
        // day -30, 12_000 cents at day -19); everything older is excluded.
        #expect(viewModel.revenueSummary.count == 2)
        #expect(viewModel.revenueSummary.grossCents == 24_000)
        #expect(viewModel.revenueSummary.netCents == 21_600)

        // Recent activity: newest first, capped at 5, nothing from the future.
        #expect(viewModel.recentActivity.count == 5)
        let occurredDates = viewModel.recentActivity.map(\.occurredAt)
        #expect(occurredDates == occurredDates.sorted(by: >))
        #expect(viewModel.recentActivity.allSatisfy { $0.occurredAt <= now })
        // The single newest activity item across all engagements is Morgan
        // Chen's bodyweight entry recorded exactly at referenceDate.
        #expect(viewModel.recentActivity.first?.clientName == "Morgan Chen")
        #expect(viewModel.recentActivity.first?.occurredAt == now)
    }

    @Test("professionalName resolves the signed-in coach's own display name, for the header avatar")
    func professionalNameResolves() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let now = InMemoryStore.referenceDate

        let viewModel = TodayViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live, clock: { now })
        #expect(viewModel.professionalName == "Coach")

        await viewModel.load()

        #expect(viewModel.professionalName == professional.displayName)
    }

    @Test("an engagement-less professional sees empty sections, not an error")
    func emptyProfessionalSeesEmptyDashboard() async {
        let backend = InMemoryStore.seeded()
        let now = InMemoryStore.referenceDate
        let viewModel = TodayViewModel(backend: backend, professionalID: Identifier(), paymentsMode: .live, clock: { now })

        await viewModel.load()

        #expect(viewModel.upcomingSessions.isEmpty)
        #expect(viewModel.recentActivity.isEmpty)
        #expect(viewModel.revenueSummary == .zero)
        #expect(viewModel.loadErrorMessage == nil)
    }

    @Test(".free mode never surfaces revenue, even though the seeded professional has succeeded payments")
    func freeModeRevenueStaysZero() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let now = InMemoryStore.referenceDate

        // Sanity: this professional genuinely has revenue in `.live` mode —
        // otherwise this test wouldn't be isolating the mode's effect.
        let liveViewModel = TodayViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live, clock: { now })
        await liveViewModel.load()
        #expect(!liveViewModel.revenueSummary.isEmpty)

        let freeViewModel = TodayViewModel(backend: backend, professionalID: professional.id, paymentsMode: .free, clock: { now })
        await freeViewModel.load()

        #expect(freeViewModel.revenueSummary == .zero)
        #expect(freeViewModel.loadErrorMessage == nil)
        // Upcoming sessions and activity are unaffected by payments mode.
        #expect(freeViewModel.upcomingSessions.count == liveViewModel.upcomingSessions.count)
        #expect(freeViewModel.recentActivity.count == liveViewModel.recentActivity.count)
    }

    @Test("a failing message fetch surfaces loadErrorMessage instead of hanging")
    func failingMessagesSurfacesLoadError() async throws {
        let seeded = InMemoryStore.seeded()
        let people = try await seeded.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let now = InMemoryStore.referenceDate

        let backend = TodayMessagesOverrideBackend(base: seeded, messages: TodayAlwaysFailingMessageRepository())
        let viewModel = TodayViewModel(backend: backend, professionalID: professional.id, paymentsMode: .live, clock: { now })

        await viewModel.load()

        #expect(viewModel.loadErrorMessage != nil)
    }
}

private struct TodayAlwaysFailingMessageRepository: MessageRepository {
    struct OfflineError: Error {}
    func fetchMessages(forEngagement engagementID: Identifier<Engagement>) async throws -> [Message] { throw OfflineError() }
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> { AsyncStream { $0.finish() } }
    func send(_ message: Message) async throws {}
}

/// A `Backend` decorator that swaps in a replacement `MessageRepository`
/// while forwarding every other repository to `base` (mirrors
/// `TodayView.swift`'s `HangingEngagementsBackend`).
private struct TodayMessagesOverrideBackend: Backend {
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
