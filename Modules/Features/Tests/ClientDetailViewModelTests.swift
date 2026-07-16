import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ClientDetailViewModel against seeded data")
@MainActor
struct ClientDetailViewModelTests {
    @Test("load() surfaces the assigned program and per-metric progress points for a seeded engagement")
    func loadsProgramAndProgress() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        // Sam Patel (seeded index 2): active engagement, Strength Foundations
        // assigned, three squat1RM progress entries (185 -> 205 -> 225 lb).
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagements = try await backend.engagements.fetchEngagements(forClient: samPatel.id)
        let engagement = try #require(engagements.first)

        let viewModel = ClientDetailViewModel(
            backend: backend,
            engagementID: engagement.id,
            professionalID: engagement.professionalID,
            clock: { InMemoryStore.referenceDate }
        )
        await viewModel.load()

        #expect(viewModel.clientName == "Sam Patel")
        #expect(viewModel.loadErrorMessage == nil)
        #expect(viewModel.program?.title == "Strength Foundations")
        #expect(viewModel.trackedMetrics == [.squat1RM])
        #expect(viewModel.points(for: .squat1RM).map(\.value) == [185, 205, 225])
    }

    @Test("an engagement with no program assignment surfaces a nil program, not an error")
    func engagementWithoutAssignmentHasNoProgram() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        // Taylor Brooks (seeded index 3) has no seeded ProgramAssignment.
        let taylor = try #require(people.first { $0.displayName == "Taylor Brooks" })
        let engagements = try await backend.engagements.fetchEngagements(forClient: taylor.id)
        let engagement = try #require(engagements.first)

        let viewModel = ClientDetailViewModel(backend: backend, engagementID: engagement.id, professionalID: engagement.professionalID)
        await viewModel.load()

        #expect(viewModel.program == nil)
        #expect(viewModel.loadErrorMessage == nil)
    }

    @Test("setStatus writes a new Engagement value back through EngagementRepository")
    func setStatusWritesThroughRepository() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)
        #expect(engagement.status == .active)

        let viewModel = ClientDetailViewModel(backend: backend, engagementID: engagement.id, professionalID: engagement.professionalID)
        await viewModel.load()
        await viewModel.setStatus(.paused)

        #expect(viewModel.engagement?.status == .paused)
        let persisted = try await backend.engagements.get(engagement.id)
        #expect(persisted?.status == .paused)
    }

    @Test("completedSessionsCount and sessionRetention are derived from real seeded session data")
    func completedSessionsAndRetention() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        // Sam Patel (seeded index 2): 4 `.completed` sessions and 1
        // `.scheduled` session; engagement started 70 days before referenceDate.
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = ClientDetailViewModel(
            backend: backend,
            engagementID: engagement.id,
            professionalID: engagement.professionalID,
            clock: { InMemoryStore.referenceDate }
        )
        await viewModel.load()

        #expect(viewModel.completedSessionsCount == 4)

        let retention = try #require(viewModel.sessionRetention)
        #expect(retention.weeksWithSession <= retention.elapsedWeeks)
        #expect((0...100).contains(retention.percent))
    }

    @Test("sessionRetention is nil for a pending engagement with no started date, not a fabricated number")
    func sessionRetentionNilWithoutStartDate() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        // Alex Rivera (seeded index 0): pending, startedAt == nil.
        let alexRivera = try #require(people.first { $0.displayName == "Alex Rivera" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: alexRivera.id).first)

        let viewModel = ClientDetailViewModel(backend: backend, engagementID: engagement.id, professionalID: engagement.professionalID)
        await viewModel.load()

        #expect(viewModel.sessionRetention == nil)
    }

    @Test("saveNote persists a CoachNote through NotesRepository and clears the draft")
    func saveNotePersists() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = ClientDetailViewModel(backend: backend, engagementID: engagement.id, professionalID: professional.id)
        await viewModel.load()
        let notesBefore = viewModel.notes.count

        viewModel.draftNoteBody = "Great session today."
        await viewModel.saveNote()

        #expect(viewModel.notes.count == notesBefore + 1)
        #expect(viewModel.draftNoteBody.isEmpty)
        let persisted = try await backend.notes.notes(forEngagement: engagement.id)
        #expect(persisted.contains { $0.body == "Great session today." })
    }
}
