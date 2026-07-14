import DataInterfaces
import DesignSystem
import Domain
import Foundation
import Observation

/// View model for a single engagement's dedicated Progress screen: every
/// tracked metric's chart points (live — reflects newly logged entries
/// without a manual refresh), a `MetricKind` filter, and a consent-gated
/// photos section.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md). Subscribes to
/// `ProgressRepository.entries(forEngagement:)` for live updates; the photo
/// subscription is only ever started while
/// `EngagementRepository.photoConsent(for:)` is `true` — when consent is
/// withheld or revoked, `photos` is kept empty and no photo data is fetched
/// at all, not merely hidden in the view.
@MainActor
@Observable
public final class ProgressViewModel {
    public private(set) var entries: [ProgressEntry] = []
    public private(set) var photos: [ProgressPhoto] = []
    public private(set) var photoConsentGranted = false
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
    nonisolated(unsafe) private var photosTask: Task<Void, Never>?

    public init(backend: any Backend, engagementID: Identifier<Engagement>) {
        self.backend = backend
        self.engagementID = engagementID
    }

    deinit {
        entriesTask?.cancel()
        photosTask?.cancel()
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

    /// Loads the engagement's photo-sharing consent and a one-shot snapshot
    /// of its entries/photos (so callers see populated data the instant
    /// `load()` returns, without waiting on Task scheduling), then (re)starts
    /// the live subscriptions that keep both current afterwards.
    public func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            photoConsentGranted = try await backend.engagements.photoConsent(for: engagementID)
        } catch {
            photoConsentGranted = false
        }

        do {
            entries = try await backend.progress.fetchEntries(forEngagement: engagementID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load this engagement's progress. Pull to refresh to try again."
        }

        if photoConsentGranted {
            photos = (try? await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)) ?? []
        } else {
            photos = []
        }

        subscribeToEntries()
        refreshPhotoSubscription()
    }

    /// Writes the photo-sharing consent decision back through
    /// `EngagementRepository.setPhotoConsent(_:for:)` — an explicit action,
    /// never inferred. Revoking immediately drops any in-memory `photos`.
    public func setPhotoConsent(_ granted: Bool) async {
        do {
            try await backend.engagements.setPhotoConsent(granted, for: engagementID)
            photoConsentGranted = granted
            refreshPhotoSubscription()
        } catch {
            loadErrorMessage = "Couldn't update photo sharing. Try again."
        }
    }

    /// Persists a new `ProgressPhoto` **reference** (never image bytes) via
    /// `ProgressPhotoRepository.upsert(_:)`.
    public func addPhoto(reference: String, capturedAt: Date = Date(), source: ProgressSource = .coachRecorded) async {
        let photo = ProgressPhoto(
            id: Identifier(),
            engagementID: engagementID,
            reference: reference,
            capturedAt: capturedAt,
            source: source
        )
        do {
            _ = try await backend.progressPhotos.upsert(photo)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't save this photo. Try again."
        }
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

    /// Only ever subscribes to `progressPhotos.photos(forEngagement:)` while
    /// `photoConsentGranted` is `true`; otherwise cancels any existing
    /// subscription and clears `photos`, so withheld/revoked consent means
    /// this view model never even holds photo data in memory, not merely
    /// hides it in the UI.
    private func refreshPhotoSubscription() {
        photosTask?.cancel()
        guard photoConsentGranted else {
            photos = []
            return
        }
        photosTask = Task {
            for await photos in backend.progressPhotos.photos(forEngagement: engagementID) {
                self.photos = photos
            }
        }
    }
}
