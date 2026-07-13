import Domain

/// CRUD access to `ProgressEntry` records, plus queries scoped to an engagement
/// and, optionally, a single metric.
public protocol ProgressRepository: Sendable {
    func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry?
    func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry
    func delete(_ id: Identifier<ProgressEntry>) async throws

    /// One-shot fetch of all progress entries for an engagement.
    func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry]

    /// One-shot fetch of an engagement's progress entries for a single metric.
    func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry]

    /// Live view of an engagement's progress entries: emits the current snapshot
    /// immediately upon subscription, then again on every mutation.
    func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]>
}
