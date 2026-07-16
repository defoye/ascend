import DataInterfaces
import Domain
import Foundation

/// The default backend adapter: every repository protocol backed by in-memory
/// dictionaries, with live views implemented via `AsyncStream`.
///
/// `InMemoryBackend` is a single actor that conforms directly to every
/// `DataInterfaces` repository protocol (see the `InMemoryBackend+*.swift`
/// extension files) as well as `Backend` itself. Centralizing all mutable state
/// in one actor is what makes the `AsyncStream` fan-out (see `StreamRegistry`)
/// straightforward: a mutation and the live views it feeds always live on the
/// same executor.
///
/// `Backend`'s property requirements are synchronous (non-`async`), so they are
/// implemented as `nonisolated` computed properties that simply hand back `self`,
/// narrowed to the requested protocol. The protocol methods themselves remain
/// actor-isolated (implicitly, since they're `async`), so their bodies can touch
/// stored state directly.
public actor InMemoryBackend: Backend {
    // MARK: - Storage

    var peopleByID: [Identifier<Person>: Person] = [:]
    var professionalProfilesByID: [Identifier<ProfessionalProfile>: ProfessionalProfile] = [:]
    var engagementsByID: [Identifier<Engagement>: Engagement] = [:]
    var consentByEngagement: [Identifier<Engagement>: Bool] = [:]
    var photoConsentByEngagement: [Identifier<Engagement>: Bool] = [:]
    var programsByID: [Identifier<Program>: Program] = [:]
    var programAssignmentsByID: [Identifier<ProgramAssignment>: ProgramAssignment] = [:]
    var sessionsByID: [Identifier<Session>: Session] = [:]
    var progressEntriesByID: [Identifier<ProgressEntry>: ProgressEntry] = [:]
    var progressPhotosByID: [Identifier<ProgressPhoto>: ProgressPhoto] = [:]
    var paymentsByID: [Identifier<Payment>: Payment] = [:]
    var messagesByID: [Identifier<Message>: Message] = [:]
    var notesByID: [Identifier<CoachNote>: CoachNote] = [:]
    var availabilityWindowsByID: [Identifier<AvailabilityWindow>: AvailabilityWindow] = [:]
    var invitesByID: [Identifier<EngagementInvite>: EngagementInvite] = [:]
    var deviceTokensByToken: [String: (personID: Identifier<Person>, platform: String)] = [:]

    var currentAuthState: AuthState = .signedOut
    var registeredUsers: [String: (password: String, user: AuthenticatedUser)] = [:]

    /// The tracker vended by `analytics`. A `RecordingAnalyticsTracker` by
    /// default so previews/tests/the DEBUG demo build can assert against it
    /// without any real analytics SDK; a production adapter would inject a
    /// live one instead (see docs/BACKEND.md).
    let analyticsTracker: any AnalyticsTracking

    // MARK: - Live view registries

    var engagementRegistry = StreamRegistry<Identifier<Person>, [Engagement]>()
    var sessionRegistry = StreamRegistry<Identifier<Engagement>, [Session]>()
    var progressRegistry = StreamRegistry<Identifier<Engagement>, [ProgressEntry]>()
    var progressPhotoRegistry = StreamRegistry<Identifier<Engagement>, [ProgressPhoto]>()
    var messageRegistry = StreamRegistry<Identifier<Engagement>, [Message]>()
    var authRegistry = StreamRegistry<SingletonKey, AuthState>()

    // MARK: - Init

    /// An empty backend with no seed data. Prefer `InMemoryBackend.seeded()` for
    /// DEBUG builds, previews, and tests.
    public init(analyticsTracker: any AnalyticsTracking = RecordingAnalyticsTracker()) {
        self.analyticsTracker = analyticsTracker
    }

    /// Builds a backend preloaded with `MockData`, synchronously — no `await`
    /// needed at the call site. Safe because actor initializers run their body
    /// before the actor is shared with any other task, so direct stored-property
    /// assignment here never races with a concurrent isolated call.
    init(mockData: MockData.Snapshot, analyticsTracker: any AnalyticsTracking = RecordingAnalyticsTracker()) {
        self.analyticsTracker = analyticsTracker
        peopleByID = Dictionary(uniqueKeysWithValues: mockData.people.map { ($0.id, $0) })
        professionalProfilesByID = Dictionary(uniqueKeysWithValues: mockData.professionalProfiles.map { ($0.id, $0) })
        engagementsByID = Dictionary(uniqueKeysWithValues: mockData.engagements.map { ($0.id, $0) })
        consentByEngagement = mockData.consentByEngagement
        photoConsentByEngagement = mockData.photoConsentByEngagement
        programsByID = Dictionary(uniqueKeysWithValues: mockData.programs.map { ($0.id, $0) })
        programAssignmentsByID = Dictionary(uniqueKeysWithValues: mockData.programAssignments.map { ($0.id, $0) })
        sessionsByID = Dictionary(uniqueKeysWithValues: mockData.sessions.map { ($0.id, $0) })
        progressEntriesByID = Dictionary(uniqueKeysWithValues: mockData.progressEntries.map { ($0.id, $0) })
        progressPhotosByID = Dictionary(uniqueKeysWithValues: mockData.progressPhotos.map { ($0.id, $0) })
        paymentsByID = Dictionary(uniqueKeysWithValues: mockData.payments.map { ($0.id, $0) })
        messagesByID = Dictionary(uniqueKeysWithValues: mockData.messages.map { ($0.id, $0) })
        notesByID = Dictionary(uniqueKeysWithValues: mockData.notes.map { ($0.id, $0) })
        availabilityWindowsByID = Dictionary(uniqueKeysWithValues: mockData.availabilityWindows.map { ($0.id, $0) })
        registeredUsers = [mockData.demoCredentials.email: (mockData.demoCredentials.password, mockData.demoCredentials.user)]
        currentAuthState = .signedIn(mockData.demoCredentials.user)
    }

    /// A backend preloaded with deterministic `MockData` — the default DEBUG
    /// backend (see docs/BACKEND.md).
    ///
    /// - Parameter analyticsTracker: The analytics seam to vend from
    ///   `analytics`. Defaults to a `RecordingAnalyticsTracker` so tests can
    ///   inject their own recording spy and assert exactly which events fired
    ///   (with no PII) against seeded data — see `AnalyticsNoPIITests`.
    public static func seeded(analyticsTracker: any AnalyticsTracking = RecordingAnalyticsTracker()) -> InMemoryBackend {
        InMemoryBackend(mockData: MockData.build(), analyticsTracker: analyticsTracker)
    }

    // MARK: - Backend

    nonisolated public var people: any PersonRepository { self }
    nonisolated public var professionals: any ProfessionalRepository { self }
    nonisolated public var engagements: any EngagementRepository { self }
    nonisolated public var programs: any ProgramRepository { self }
    nonisolated public var sessions: any SessionRepository { self }
    nonisolated public var progress: any ProgressRepository { self }
    nonisolated public var progressPhotos: any ProgressPhotoRepository { self }
    nonisolated public var payments: any PaymentRepository { self }
    nonisolated public var paymentGateway: any PaymentGateway { self }
    nonisolated public var messages: any MessageRepository { self }
    nonisolated public var outcomes: any OutcomeRepository { self }
    nonisolated public var notes: any NotesRepository { self }
    nonisolated public var availability: any AvailabilityRepository { self }
    nonisolated public var invites: any InviteRepository { self }
    nonisolated public var auth: any AuthGateway { self }
    nonisolated public var analytics: any AnalyticsTracking { analyticsTracker }
    nonisolated public var deviceTokens: any DeviceTokenRepository { self }
}
