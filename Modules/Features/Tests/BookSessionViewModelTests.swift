import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("BookSessionViewModel against seeded data")
@MainActor
struct BookSessionViewModelTests {
    @Test("load() excludes ended/completed engagements and defaults the selection to the first option")
    func loadExcludesEndedAndCompletedEngagements() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })

        let viewModel = BookSessionViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate })
        await viewModel.load()

        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let expectedBookableCount = engagements.filter { $0.status != .ended && $0.status != .completed }.count

        #expect(viewModel.engagementOptions.count == expectedBookableCount)
        #expect(viewModel.selectedEngagementID != nil)
        #expect(viewModel.selectedEngagementID == viewModel.engagementOptions.first?.engagementID)
    }

    @Test("book() with no selection returns nil and saves nothing")
    func bookWithNoSelectionFails() async throws {
        let backend = InMemoryStore.seeded()
        let viewModel = BookSessionViewModel(backend: backend, professionalID: Identifier(), clock: { InMemoryStore.referenceDate })

        let result = await viewModel.book()

        #expect(result == nil)
    }

    @Test("book() schedules a reminder via the injected mock scheduler")
    func bookSchedulesReminderOnMock() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first { $0.status == .active })

        let reminders = MockSessionReminderScheduler()
        let viewModel = BookSessionViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate }, reminders: reminders)
        viewModel.selectedEngagementID = engagement.id
        viewModel.scheduledAt = InMemoryStore.referenceDate.addingTimeInterval(86_400)

        let saved = try #require(await viewModel.book())

        let scheduledIDs = await reminders.scheduledSessionIDs
        #expect(scheduledIDs == [saved.id])
    }
}
