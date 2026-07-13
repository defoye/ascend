import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("AddClientViewModel against seeded data")
@MainActor
struct AddClientViewModelTests {
    @Test("saving a new-person client creates a Person and an Engagement linking it to the professional")
    func savesNewPersonAndEngagement() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let beforeEngagementCount = try await backend.engagements.fetchEngagements(forProfessional: professional.id).count
        let beforePeopleCount = people.count

        let viewModel = AddClientViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate })
        viewModel.mode = .newPerson
        viewModel.name = "Riley Jordan"
        viewModel.selectedGoalKind = .buildMuscle

        let saved = await viewModel.save()
        #expect(saved)

        let afterPeople = try await backend.people.list()
        #expect(afterPeople.count == beforePeopleCount + 1)
        let newPerson = try #require(afterPeople.first { $0.displayName == "Riley Jordan" })
        #expect(newPerson.roles == [.consumer])
        #expect(newPerson.goals.first?.kind == .buildMuscle)

        let afterEngagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        #expect(afterEngagements.count == beforeEngagementCount + 1)
        let newEngagement = try #require(afterEngagements.first { $0.clientID == newPerson.id })
        #expect(newEngagement.professionalID == professional.id)
        #expect(newEngagement.status == .active)
        #expect(newEngagement.startedAt == InMemoryStore.referenceDate)
    }

    @Test("existing-person mode links an eligible existing person without creating a new Person")
    func linksExistingPersonWithoutCreatingANewOne() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.roles.contains(.professional) })
        let beforePeopleCount = people.count

        let viewModel = AddClientViewModel(backend: backend, professionalID: professional.id, clock: { InMemoryStore.referenceDate })
        await viewModel.loadExistingCandidates()
        // Seeded data: every `.consumer` person is already engaged with the professional.
        #expect(viewModel.existingCandidates.isEmpty)

        let unaffiliated = Person(id: Identifier(), displayName: "Casey Unaffiliated", roles: [.consumer], goals: [])
        _ = try await backend.people.upsert(unaffiliated)
        await viewModel.loadExistingCandidates()
        #expect(viewModel.existingCandidates.contains { $0.id == unaffiliated.id })

        viewModel.mode = .existingPerson
        viewModel.selectedExistingPersonID = unaffiliated.id
        let saved = await viewModel.save()
        #expect(saved)

        let afterPeople = try await backend.people.list()
        // Only the manually-upserted unaffiliated person was added; save() must not create another.
        #expect(afterPeople.count == beforePeopleCount + 1)

        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let newEngagement = try #require(engagements.first { $0.clientID == unaffiliated.id })
        #expect(newEngagement.professionalID == professional.id)
        #expect(newEngagement.status == .active)
    }

    @Test("isValid requires a non-empty name in new-person mode and a selection in existing-person mode")
    func isValidReflectsMode() {
        let viewModel = AddClientViewModel(backend: InMemoryStore.seeded(), professionalID: Identifier())

        viewModel.mode = .newPerson
        #expect(!viewModel.isValid)
        viewModel.name = "   "
        #expect(!viewModel.isValid)
        viewModel.name = "Jordan"
        #expect(viewModel.isValid)

        viewModel.mode = .existingPerson
        #expect(!viewModel.isValid)
        viewModel.selectedExistingPersonID = Identifier()
        #expect(viewModel.isValid)
    }
}
