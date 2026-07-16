import DataInterfaces
import DesignSystem
import Domain
import SwiftUI

/// The coach's daily home surface: upcoming sessions, recent client
/// activity, and a revenue snapshot (see docs/design/DESIGN_SPEC.md).
public struct TodayView: View {
    // Not `private`: `TodayView+Skeleton.swift` and `TodayView+Sections.swift`
    // (same-type extensions in different files, split out purely to stay
    // under SwiftLint's `file_length`) need access — `private` is
    // file-scoped in Swift.
    @State var viewModel: TodayViewModel
    @State var showingSchedule = false
    @State var todayDestination: TodayDestination?
    let now: @Sendable () -> Date
    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let reminders: any SessionReminderScheduling

    public init(
        viewModel: TodayViewModel,
        backend: any Backend,
        professionalID: Identifier<Person>,
        now: @escaping @Sendable () -> Date = { Date() },
        reminders: any SessionReminderScheduling = LiveSessionReminderScheduler()
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.backend = backend
        self.professionalID = professionalID
        self.now = now
        self.reminders = reminders
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.space6) {
                    if let loadErrorMessage = viewModel.loadErrorMessage {
                        ErrorBanner(message: loadErrorMessage, retry: { Task { await viewModel.load() } })
                            .padding(.horizontal, Spacing.space4)
                    }
                    // Error kit (docs/design/handoff/HANDOFF_README.md §06):
                    // stale content (header included) stays visible under the
                    // banner, dimmed to 55%, rather than being replaced or hidden.
                    VStack(alignment: .leading, spacing: Spacing.space6) {
                        header
                        content
                    }
                    .opacity(viewModel.loadErrorMessage != nil ? 0.55 : 1)
                }
                .padding(.vertical, Spacing.space4)
            }
            .background(Color.Ascend.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSchedule = true } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Schedule")
                }
            }
            .navigationDestination(isPresented: $showingSchedule) {
                ScheduleView(
                    viewModel: ScheduleViewModel(backend: backend, professionalID: professionalID, clock: now, reminders: reminders),
                    backend: backend,
                    professionalID: professionalID,
                    clock: now,
                    reminders: reminders
                )
            }
            .navigationDestination(item: $todayDestination) { destination in
                switch destination {
                case let .client(engagementID):
                    ClientDetailView(
                        viewModel: ClientDetailViewModel(backend: backend, engagementID: engagementID, professionalID: professionalID)
                    )
                case let .messageThread(engagementID):
                    MessageThreadView(
                        viewModel: MessageThreadViewModel(backend: backend, engagementID: engagementID, selfID: professionalID)
                    )
                }
            }
            .refreshable { await viewModel.load() }
            .task { await viewModel.load() }
        }
    }
}

/// Where a tapped "Today" row navigates: an upcoming-session row and a
/// progress-log activity row both open the client's detail screen; a
/// client-message activity row opens that engagement's message thread.
///
/// Not `private`: `TodayView+Sections.swift` (a same-type extension in a
/// different file) returns this from `activityDestination(for:)` —
/// `private` is file-scoped in Swift.
enum TodayDestination: Identifiable, Hashable {
    case client(engagementID: Identifier<Engagement>)
    case messageThread(engagementID: Identifier<Engagement>)

    var id: Self { self }
}

/// The header's "Tuesday, Jul 15" date line (see
/// docs/design/handoff/HANDOFF_README.md §01).
enum TodayHeaderDateFormatter {
    nonisolated(unsafe) private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}

/// USD cents -> dollars formatting with tabular figures (see
/// docs/design/DESIGN_SPEC.md §2.3).
enum CurrencyFormatter {
    /// `NumberFormatter` construction is expensive; built once and reused
    /// across every call rather than per-invocation. `nonisolated(unsafe)`:
    /// never mutated after initialization, and `NumberFormatter.string(from:)`
    /// is safe to call concurrently for reads (see `ProgressViewModel` for
    /// the same pattern applied to `Task` properties).
    nonisolated(unsafe) private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    static func dollars(fromCents cents: Int) -> String {
        let value = Double(cents) / 100
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

/// Human-readable display for a `MetricKind`/`MetricValue` pair.
enum MetricFormatter {
    static func format(_ value: MetricValue) -> String {
        let number = value.value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value.value)
            : String(format: "%.1f", value.value)
        return "\(number) \(unitLabel(value.unit))"
    }

    private static func unitLabel(_ unit: MetricUnit) -> String {
        switch unit {
        case .lb: "lb"
        case .kg: "kg"
        case .inch: "in"
        case .cm: "cm"
        case .percent: "%"
        case .bpm: "bpm"
        case .seconds: "sec"
        }
    }
}

extension MetricKind {
    var displayName: String {
        switch self {
        case .bodyweight: "bodyweight"
        case .waistCircumference: "waist circumference"
        case .squat1RM: "squat 1RM"
        case .bench1RM: "bench 1RM"
        case .deadlift1RM: "deadlift 1RM"
        case .bodyFatPercentage: "body fat %"
        case .restingHeartRate: "resting heart rate"
        case .fiveKTime: "5K time"
        }
    }
}

#Preview("TodayView - Light") {
    TodayPreview(paymentsMode: .live)
        .preferredColorScheme(.light)
}

#Preview("TodayView - Dark") {
    TodayPreview(paymentsMode: .live)
        .preferredColorScheme(.dark)
}

#Preview("TodayView - Free (no revenue) - Light") {
    TodayPreview(paymentsMode: .free)
        .preferredColorScheme(.light)
}

#Preview("TodayView - Loading - Light") {
    TodayLoadingPreview()
        .preferredColorScheme(.light)
}

#Preview("TodayView - Loading - Dark") {
    TodayLoadingPreview()
        .preferredColorScheme(.dark)
}

/// A self-contained preview fixture, independent of any backend module (see
/// docs/CONVENTIONS.md — Features may not import a concrete backend). Feeds
/// the view model's observable state directly rather than loading it, since
/// `TodayViewModel` only depends on `any Backend`.
private struct TodayPreview: View {
    let paymentsMode: PaymentsMode

    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = PreviewBackend(professionalID: professionalID)
        TodayView(
            viewModel: TodayViewModel(backend: backend, professionalID: professionalID, paymentsMode: paymentsMode),
            backend: backend,
            professionalID: professionalID,
            reminders: MockSessionReminderScheduler()
        )
    }
}

/// Forces `TodayView`'s loading-skeleton state for review, without adding a
/// preview-only knob to `TodayViewModel`'s public API: `load()` awaits
/// `fetchEngagements`, which this backend never resolves, so `isLoading`
/// stays `true` for the life of the preview (see docs/design/handoff/
/// HANDOFF_README.md §01 "Loading skeleton").
private struct TodayLoadingPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let backend = HangingEngagementsBackend(base: PreviewBackend(professionalID: professionalID))
        TodayView(
            viewModel: TodayViewModel(backend: backend, professionalID: professionalID, paymentsMode: .live),
            backend: backend,
            professionalID: professionalID,
            reminders: MockSessionReminderScheduler()
        )
    }
}

private struct HangingEngagementsBackend: Backend {
    let base: any Backend
    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { base.professionals }
    var engagements: any EngagementRepository { HangingEngagementRepository(base: base.engagements) }
    var programs: any ProgramRepository { base.programs }
    var sessions: any SessionRepository { base.sessions }
    var progress: any ProgressRepository { base.progress }
    var progressPhotos: any ProgressPhotoRepository { base.progressPhotos }
    var payments: any PaymentRepository { base.payments }
    var paymentGateway: any PaymentGateway { base.paymentGateway }
    var messages: any MessageRepository { base.messages }
    var outcomes: any OutcomeRepository { base.outcomes }
    var notes: any NotesRepository { base.notes }
    var availability: any AvailabilityRepository { base.availability }
    var auth: any AuthGateway { base.auth }
    var analytics: any AnalyticsTracking { base.analytics }
}

private struct HangingEngagementRepository: EngagementRepository {
    let base: any EngagementRepository
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? { try await base.get(id) }
    func upsert(_ engagement: Engagement) async throws -> Engagement { try await base.upsert(engagement) }
    func delete(_ id: Identifier<Engagement>) async throws { try await base.delete(id) }
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        try await Task.sleep(nanoseconds: .max)
        return []
    }
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        base.engagements(forProfessional: professionalID)
    }
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] {
        try await base.fetchEngagements(forClient: clientID)
    }
    func consent(for engagementID: Identifier<Engagement>) async throws -> Bool { try await base.consent(for: engagementID) }
    func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        try await base.setConsent(granted, for: engagementID)
    }
    func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool {
        try await base.photoConsent(for: engagementID)
    }
    func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {
        try await base.setPhotoConsent(granted, for: engagementID)
    }
}
