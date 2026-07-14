import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("LogProgressViewModel")
@MainActor
struct LogProgressViewModelTests {
    @Test("save() persists a ProgressEntry through ProgressRepository, defaulting source to coachRecorded")
    func savePersistsEntryWithDefaultSource() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = LogProgressViewModel(backend: backend, engagementID: engagement.id, metric: .squat1RM)
        #expect(viewModel.unit == .lb) // sensible default unit for squat1RM
        viewModel.valueText = "245"

        let saved = try #require(await viewModel.save())
        #expect(saved.metric == .squat1RM)
        #expect(saved.value.value == 245)
        #expect(saved.value.unit == .lb)
        #expect(saved.source == .coachRecorded)

        let persisted = try await backend.progress.fetchEntries(forEngagement: engagement.id, metric: .squat1RM)
        #expect(persisted.contains { $0.id == saved.id })
    }

    @Test("source is an injectable initializer parameter, not hardcoded, so client self-logging works later")
    func sourceIsInjectable() async throws {
        let backend = InMemoryStore.seeded()
        let viewModel = LogProgressViewModel(
            backend: backend,
            engagementID: Identifier(),
            metric: .bodyweight,
            source: .clientSelfReported
        )
        viewModel.valueText = "180"

        let saved = try #require(await viewModel.save())
        #expect(saved.source == .clientSelfReported)
    }

    @Test("isValid requires a parseable numeric value")
    func isValidRequiresParseableNumber() {
        let backend = InMemoryStore.seeded()
        let viewModel = LogProgressViewModel(backend: backend, engagementID: Identifier())

        #expect(viewModel.isValid == false)
        viewModel.valueText = "not a number"
        #expect(viewModel.isValid == false)
        viewModel.valueText = "150"
        #expect(viewModel.isValid == true)
    }

    @Test("save() with an unparseable value does not write anything and returns nil")
    func saveWithInvalidValueDoesNothing() async throws {
        let backend = InMemoryStore.seeded()
        let engagementID = Identifier<Engagement>()
        let viewModel = LogProgressViewModel(backend: backend, engagementID: engagementID)
        viewModel.valueText = "oops"

        let saved = await viewModel.save()
        #expect(saved == nil)

        let persisted = try await backend.progress.fetchEntries(forEngagement: engagementID)
        #expect(persisted.isEmpty)
    }

    @Test("changing metric resets the unit to that metric's sensible default")
    func metricChangeResetsUnit() {
        let backend = InMemoryStore.seeded()
        let viewModel = LogProgressViewModel(backend: backend, engagementID: Identifier(), metric: .bodyweight)
        #expect(viewModel.unit == .lb)

        viewModel.metric = .fiveKTime
        viewModel.metricChanged()
        #expect(viewModel.unit == .seconds)

        viewModel.metric = .bodyFatPercentage
        viewModel.metricChanged()
        #expect(viewModel.unit == .percent)
    }
}
