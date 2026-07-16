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
}
