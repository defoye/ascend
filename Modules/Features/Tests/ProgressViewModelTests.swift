import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

private struct TimeoutError: Error {}

@Suite("ProgressViewModel against seeded data")
@MainActor
struct ProgressViewModelTests {
    @Test("load() surfaces tracked metrics and chart points for a seeded engagement")
    func loadsTrackedMetricsAndPoints() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = ProgressViewModel(backend: backend, engagementID: engagement.id)
        await viewModel.load()

        #expect(viewModel.trackedMetrics == [.squat1RM])
        #expect(viewModel.points(for: .squat1RM).map(\.value) == [185, 205, 225])
    }

    @Test("logging a new ProgressEntry through the repository updates tracked metrics/points/deltas live")
    func liveEntryUpdatesReflectInViewModel() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = ProgressViewModel(backend: backend, engagementID: engagement.id)
        await viewModel.load()
        #expect(viewModel.points(for: .squat1RM).map(\.value) == [185, 205, 225])

        let newEntry = ProgressEntry(
            id: Identifier(),
            engagementID: engagement.id,
            metric: .squat1RM,
            value: MetricValue(value: 235, unit: .lb),
            recordedAt: InMemoryStore.referenceDate.addingTimeInterval(3_600),
            source: .coachRecorded
        )
        _ = try await backend.progress.upsert(newEntry)

        try await waitUntil { viewModel.points(for: .squat1RM).map(\.value).contains(235) }

        #expect(viewModel.points(for: .squat1RM).map(\.value) == [185, 205, 225, 235])
    }

    @Test("a brand-new metric introduced by a fresh entry appears in trackedMetrics live")
    func newMetricAppearsLive() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let samPatel = try #require(people.first { $0.displayName == "Sam Patel" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: samPatel.id).first)

        let viewModel = ProgressViewModel(backend: backend, engagementID: engagement.id)
        await viewModel.load()
        #expect(viewModel.trackedMetrics == [.squat1RM])

        let bodyweightEntry = ProgressEntry(
            id: Identifier(),
            engagementID: engagement.id,
            metric: .bodyweight,
            value: MetricValue(value: 190, unit: .lb),
            recordedAt: InMemoryStore.referenceDate,
            source: .coachRecorded
        )
        _ = try await backend.progress.upsert(bodyweightEntry)

        try await waitUntil { viewModel.trackedMetrics.contains(.bodyweight) }

        #expect(Set(viewModel.trackedMetrics) == [.squat1RM, .bodyweight])
    }

    @Test("metricFilter narrows filteredMetrics to a single tracked metric; nil means All")
    func metricFilterNarrowsResults() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)

        let viewModel = ProgressViewModel(backend: backend, engagementID: engagement.id)
        await viewModel.load()
        #expect(viewModel.filteredMetrics == [.bodyweight])

        viewModel.metricFilter = .bodyweight
        #expect(viewModel.filteredMetrics == [.bodyweight])

        viewModel.metricFilter = .squat1RM
        #expect(viewModel.filteredMetrics.isEmpty)
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw TimeoutError() }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
