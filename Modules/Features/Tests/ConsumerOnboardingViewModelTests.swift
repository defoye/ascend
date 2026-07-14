import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("ConsumerOnboardingViewModel")
@MainActor
struct ConsumerOnboardingViewModelTests {
    @Test("submit() appends a Goal built from the form state to the client's Person.goals and persists it")
    func submitAppendsGoalAndPersists() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let goalsBefore = morganChen.goals.count

        let viewModel = ConsumerOnboardingViewModel(backend: backend, clientID: morganChen.id)
        viewModel.goalKind = .improveMobility
        viewModel.experienceLevel = .intermediate

        let goal = try #require(await viewModel.submit())
        #expect(goal.kind == .improveMobility)

        let updatedPerson = try #require(try await backend.people.get(morganChen.id))
        #expect(updatedPerson.goals.count == goalsBefore + 1)
        #expect(updatedPerson.goals.contains { $0.id == goal.id && $0.kind == .improveMobility })
    }

    @Test("submit() with a known engagement sends a summary Message capturing experience/injuries/preferences to the coach")
    func submitSendsIntakeSummaryMessageWhenEngagementKnown() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morganChen.id).first)

        let viewModel = ConsumerOnboardingViewModel(backend: backend, clientID: morganChen.id, engagementID: engagement.id)
        viewModel.goalKind = .recoverFromInjury
        viewModel.experienceLevel = .beginner
        viewModel.injuriesText = "Tweaked left knee"
        viewModel.preferencesText = "Mornings only"

        _ = await viewModel.submit()

        var messages: [Message] = []
        for await snapshot in backend.messages.messages(in: engagement.id) {
            messages = snapshot
            break
        }
        #expect(messages.contains {
            $0.authorID == morganChen.id
                && $0.body.contains("Tweaked left knee")
                && $0.body.contains("Mornings only")
        })
    }

    @Test("submit() without a known engagement still saves the Goal and does not throw")
    func submitWithoutEngagementStillSavesGoal() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })

        let viewModel = ConsumerOnboardingViewModel(backend: backend, clientID: morganChen.id, engagementID: nil)
        viewModel.goalKind = .generalHealth

        let goal = await viewModel.submit()
        #expect(goal != nil)
        #expect(viewModel.saveErrorMessage == nil)
    }

    @Test("intakeSummary omits blank free-text fields")
    func intakeSummaryOmitsBlankFields() {
        let summary = ConsumerOnboardingViewModel.intakeSummary(goalKind: .buildMuscle, experience: .advanced, injuries: "  ", preferences: "")
        #expect(!summary.contains("Injuries"))
        #expect(!summary.contains("Preferences"))
        #expect(summary.contains("Build muscle") || summary.lowercased().contains("build muscle"))
    }
}
