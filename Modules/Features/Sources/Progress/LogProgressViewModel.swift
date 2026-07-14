import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for logging a single `ProgressEntry`: pick a metric, enter a
/// numeric value in an appropriate unit, and a date (defaulting to now).
///
/// `source` defaults to `.coachRecorded` but is an injectable initializer
/// parameter, never hardcoded at the call site — the same view model (and
/// `LogProgressView`) will back client self-logging later by constructing it
/// with `source: .clientSelfReported` instead. Depends only on `any Backend`
/// (see docs/ARCHITECTURE.md); the write goes through
/// `ProgressRepository.upsert(_:)`, never a direct store mutation (see
/// docs/BACKEND.md).
@MainActor
@Observable
public final class LogProgressViewModel {
    public var metric: MetricKind
    public var valueText = ""
    public var unit: MetricUnit
    public var recordedAt: Date
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let engagementID: Identifier<Engagement>
    private let source: ProgressSource
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        engagementID: Identifier<Engagement>,
        metric: MetricKind = .bodyweight,
        source: ProgressSource = .coachRecorded,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.engagementID = engagementID
        self.metric = metric
        self.source = source
        self.clock = clock
        unit = metric.defaultUnit
        recordedAt = clock()
    }

    /// The units it makes sense to log `metric` in, for the unit picker.
    public var availableUnits: [MetricUnit] { metric.compatibleUnits }

    /// Whether `valueText` parses to a number — the "Log progress" button's
    /// enabled condition.
    public var isValid: Bool { Double(valueText) != nil }

    /// Called when the view's metric picker changes selection, so the unit
    /// resets to that metric's sensible default rather than staying on a
    /// unit that no longer applies (e.g. `bpm` left over from heart rate
    /// after switching to bodyweight).
    public func metricChanged() {
        unit = metric.defaultUnit
    }

    /// Constructs a fresh `ProgressEntry` from the current form state and
    /// persists it via `ProgressRepository.upsert(_:)`.
    @discardableResult
    public func save() async -> ProgressEntry? {
        guard let value = Double(valueText) else { return nil }
        isSaving = true
        defer { isSaving = false }

        let entry = ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: recordedAt,
            source: source
        )
        do {
            let saved = try await backend.progress.upsert(entry)
            saveErrorMessage = nil
            return saved
        } catch {
            saveErrorMessage = "Couldn't save this entry. Try again."
            return nil
        }
    }
}

extension MetricKind {
    /// The unit `LogProgressView`'s picker defaults to for this metric.
    var defaultUnit: MetricUnit {
        compatibleUnits.first ?? .lb
    }

    /// The units that make sense to express this metric in, e.g. weight
    /// metrics offer `lb`/`kg` but never `bpm`.
    var compatibleUnits: [MetricUnit] {
        switch self {
        case .bodyweight, .squat1RM, .bench1RM, .deadlift1RM:
            [.lb, .kg]
        case .waistCircumference:
            [.inch, .cm]
        case .bodyFatPercentage:
            [.percent]
        case .restingHeartRate:
            [.bpm]
        case .fiveKTime:
            [.seconds]
        }
    }
}
