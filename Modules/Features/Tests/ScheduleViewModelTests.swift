import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ScheduleViewModel session lifecycle against seeded data")
@MainActor
struct ScheduleViewModelTests {
    /// Finds the seeded engagement whose client has `name`, and the
    /// `.scheduled` session on it — every seeded client with a scheduled
    /// session has exactly one.
    private func scheduledSession(forClientNamed name: String, backend: InMemoryBackend, professionalID: Identifier<Person>) async throws -> ScheduledSession {
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
        for engagement in engagements {
            guard let client = try await backend.people.get(engagement.clientID), client.displayName == name else { continue }
            let sessions = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
            if let scheduled = sessions.first(where: { $0.status == .scheduled }) {
                return ScheduledSession(session: scheduled, clientName: name)
            }
        }
        Issue.record("No scheduled session found for \(name)")
        return ScheduledSession(session: Session(id: Identifier(), engagementID: Identifier(), scheduledAt: Date(), status: .scheduled), clientName: name)
    }

    private func makeViewModel(backend: InMemoryBackend, professionalID: Identifier<Person>, reminders: MockSessionReminderScheduler) -> ScheduleViewModel {
        ScheduleViewModel(backend: backend, professionalID: professionalID, clock: { InMemoryStore.referenceDate }, reminders: reminders)
    }

    @Test("booking a session persists it as .scheduled and it appears via fetchSessions and the schedule")
    func bookingPersistsScheduledSession() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first)

        let reminders = MockSessionReminderScheduler()
        let bookViewModel = BookSessionViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate }, reminders: reminders)
        await bookViewModel.load()
        bookViewModel.selectedEngagementID = engagement.id
        let bookedAt = InMemoryStore.referenceDate.addingTimeInterval(3 * 86_400)
        bookViewModel.scheduledAt = bookedAt

        let saved = try #require(await bookViewModel.book())
        #expect(saved.status == .scheduled)
        #expect(saved.engagementID == engagement.id)

        let fetched = try await backend.sessions.fetchSessions(forEngagement: engagement.id)
        #expect(fetched.contains { $0.id == saved.id && $0.status == .scheduled })

        let scheduleViewModel = makeViewModel(backend: backend, professionalID: professional.id, reminders: reminders)
        await scheduleViewModel.load()
        #expect(scheduleViewModel.allSessions.contains { $0.id == saved.id })

        // Reminder scheduling: booking calls scheduleReminder on the injected mock.
        let scheduledIDs = await reminders.scheduledSessionIDs
        #expect(scheduledIDs.contains(saved.id))
    }

    @Test("completing a .scheduled session persists .completed and stays queryable per engagement")
    func completingPersistsCompletedAndIsQueryable() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let reminders = MockSessionReminderScheduler()
        let target = try await scheduledSession(forClientNamed: "Morgan Chen", backend: backend, professionalID: professional.id)

        let viewModel = makeViewModel(backend: backend, professionalID: professional.id, reminders: reminders)
        await viewModel.load()
        await viewModel.complete(target)

        let updated = try #require(try await backend.sessions.get(target.id))
        #expect(updated.status == .completed)

        // The "activity" pillar for VerifiedOutcome.derive: completed sessions
        // stay queryable per engagement.
        let completedSessions = try await backend.sessions.fetchSessions(forEngagement: target.engagementID).filter { $0.status == .completed }
        #expect(completedSessions.contains { $0.id == target.id })

        // Completing does not touch reminders (only cancelling does).
        let cancelledIDs = await reminders.cancelledSessionIDs
        #expect(!cancelledIDs.contains(target.id))
    }

    @Test("cancelling a .scheduled session persists .cancelled and cancels its reminder")
    func cancellingPersistsCancelledAndCancelsReminder() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let reminders = MockSessionReminderScheduler()
        let target = try await scheduledSession(forClientNamed: "Sam Patel", backend: backend, professionalID: professional.id)

        let viewModel = makeViewModel(backend: backend, professionalID: professional.id, reminders: reminders)
        await viewModel.load()
        await viewModel.cancel(target)

        let updated = try #require(try await backend.sessions.get(target.id))
        #expect(updated.status == .cancelled)

        let cancelledIDs = await reminders.cancelledSessionIDs
        #expect(cancelledIDs.contains(target.id))
    }

    @Test("marking a newly booked .scheduled session a no-show persists .noShow")
    func markingNoShowPersists() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first)

        let session = Session(
            id: Identifier(),
            engagementID: engagement.id,
            scheduledAt: InMemoryStore.referenceDate.addingTimeInterval(2 * 86_400),
            status: .scheduled
        )
        _ = try await backend.sessions.upsert(session)

        let reminders = MockSessionReminderScheduler()
        let viewModel = makeViewModel(backend: backend, professionalID: professional.id, reminders: reminders)
        await viewModel.load()
        let scheduled = ScheduledSession(session: session, clientName: "Client")
        await viewModel.markNoShow(scheduled)

        let updated = try #require(try await backend.sessions.get(session.id))
        #expect(updated.status == .noShow)
    }

    @Test("an already-terminal session cannot be transitioned again")
    func terminalSessionCannotTransitionAgain() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let reminders = MockSessionReminderScheduler()
        let target = try await scheduledSession(forClientNamed: "Morgan Chen", backend: backend, professionalID: professional.id)

        let viewModel = makeViewModel(backend: backend, professionalID: professional.id, reminders: reminders)
        await viewModel.load()
        await viewModel.complete(target)
        // Attempting to cancel an already-completed session should be a no-op.
        let stillCompleted = ScheduledSession(session: Session(id: target.id, engagementID: target.engagementID, scheduledAt: target.scheduledAt, status: .completed), clientName: target.clientName)
        await viewModel.cancel(stillCompleted)

        let updated = try #require(try await backend.sessions.get(target.id))
        #expect(updated.status == .completed)
    }
}
