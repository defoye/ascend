import DataInterfaces
import DesignSystem
import Domain
import Observation

/// View model for a single engagement's dedicated Progress screen: every
/// tracked metric's chart points (live — reflects newly logged entries
/// without a manual refresh) and a `MetricKind` filter.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md). Subscribes to
/// `ProgressRepository.entries(forEngagement:)` for live updates.
@MainActor
@Observable
public final class ProgressViewModel {
    public private(set) var entries: [ProgressEntry] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

    /// `nil` means "All" — every tracked metric is shown.
    public var metricFilter: MetricKind?

    /// Exposed so the view can construct sibling view models (e.g.
    /// `LogProgressViewModel` for the "Log progress" sheet) against the same
    /// backend/engagement.
    public let backend: any Backend
    public let engagementID: Identifier<Engagement>

    // `nonisolated(unsafe)`: `Task` is `Sendable` and `cancel()` is
    // thread-safe, which is the only thing `deinit` (necessarily
    // `nonisolated` on a class) needs to do with these — every other access
    // happens from this MainActor-isolated type's own isolated methods.
    nonisolated(unsafe) private var entriesTask: Task<Void, Never>?

    public init(backend: any Backend, engagementID: Identifier<Engagement>) {
        self.backend = backend
        self.engagementID = engagementID
    }

    deinit {
        entriesTask?.cancel()
    }

    /// Distinct metrics with logged entries, ordered by first-logged date.
    public var trackedMetrics: [MetricKind] {
        var seen: Set<MetricKind> = []
        var ordered: [MetricKind] = []
        for entry in entries.sorted(by: { $0.recordedAt < $1.recordedAt }) where seen.insert(entry.metric).inserted {
            ordered.append(entry.metric)
        }
        return ordered
    }

    /// `trackedMetrics` narrowed to `metricFilter`, or all of them when the
    /// filter is `nil` ("All").
    public var filteredMetrics: [MetricKind] {
        guard let metricFilter else { return trackedMetrics }
        return trackedMetrics.contains(metricFilter) ? [metricFilter] : []
    }

    /// Chart-ready points for a single metric, oldest first.
    public func points(for metric: MetricKind) -> [ProgressPoint] {
        entries
            .filter { $0.metric == metric }
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { ProgressPoint(date: $0.recordedAt, value: $0.value.value) }
    }

    /// Loads a one-shot snapshot of the engagement's entries (so callers see
    /// populated data the instant `load()` returns, without waiting on Task
    /// scheduling), then (re)starts the live subscription that keeps it
    /// current afterwards.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            entries = try await backend.progress.fetchEntries(forEngagement: engagementID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load this engagement's progress. Pull to refresh to try again."
        }

        subscribeToEntries()
    }

    // MARK: - Subscriptions

    private func subscribeToEntries() {
        entriesTask?.cancel()
        entriesTask = Task {
            for await entries in backend.progress.entries(forEngagement: engagementID) {
                self.entries = entries
            }
        }
    }
}
