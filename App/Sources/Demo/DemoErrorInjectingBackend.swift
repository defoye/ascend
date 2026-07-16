#if DEBUG

import DataInterfaces
import Domain

/// The demo control panel's "error states" scenario: wraps a real `Backend`
/// and makes every repository read/write throw (live `AsyncStream` reads
/// finish empty instead, since streams have no throwing channel) — so every
/// screen's `ErrorBanner`/retry and empty-state paths are exercisable
/// without hand-authoring a broken screen per feature. `auth` and
/// `analytics` pass through untouched so the demo harness itself (and the
/// app's signed-in state) keeps working while every *product* repository
/// fails.
struct DemoErrorInjectingBackend: Backend {
    enum SimulatedError: Error, Sendable {
        case offline
    }

    let wrapped: any Backend

    var people: any PersonRepository { DemoFailingPersonRepository() }
    var professionals: any ProfessionalRepository { DemoFailingProfessionalRepository() }
    var engagements: any EngagementRepository { DemoFailingEngagementRepository() }
    var programs: any ProgramRepository { DemoFailingProgramRepository() }
    var sessions: any SessionRepository { DemoFailingSessionRepository() }
    var progress: any ProgressRepository { DemoFailingProgressRepository() }
    var progressPhotos: any ProgressPhotoRepository { DemoFailingProgressPhotoRepository() }
    var payments: any PaymentRepository { DemoFailingPaymentRepository() }
    var paymentGateway: any PaymentGateway { DemoFailingPaymentGateway() }
    var messages: any MessageRepository { DemoFailingMessageRepository() }
    var outcomes: any OutcomeRepository { DemoFailingOutcomeRepository() }
    var notes: any NotesRepository { DemoFailingNotesRepository() }
    var availability: any AvailabilityRepository { DemoFailingAvailabilityRepository() }
    var invites: any InviteRepository { DemoFailingInviteRepository() }
    var auth: any AuthGateway { wrapped.auth }
    var analytics: any AnalyticsTracking { wrapped.analytics }
}

private let offlineError = DemoErrorInjectingBackend.SimulatedError.offline

private struct DemoFailingPersonRepository: PersonRepository {
    func get(_ id: Identifier<Person>) async throws -> Person? { throw offlineError }
    func list() async throws -> [Person] { throw offlineError }
    func upsert(_ person: Person) async throws -> Person { throw offlineError }
    func delete(_ id: Identifier<Person>) async throws { throw offlineError }
}

private struct DemoFailingProfessionalRepository: ProfessionalRepository {
    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? { throw offlineError }
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? { throw offlineError }
    func listProfiles() async throws -> [ProfessionalProfile] { throw offlineError }
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile { throw offlineError }
    func delete(_ id: Identifier<ProfessionalProfile>) async throws { throw offlineError }
}

private struct DemoFailingEngagementRepository: EngagementRepository {
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? { throw offlineError }
    func upsert(_ engagement: Engagement) async throws -> Engagement { throw offlineError }
    func delete(_ id: Identifier<Engagement>) async throws { throw offlineError }
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] { throw offlineError }
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        AsyncStream { $0.finish() }
    }
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] { throw offlineError }
    func consent(for engagementID: Identifier<Engagement>) async throws -> Bool { throw offlineError }
    func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws { throw offlineError }
    func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool { throw offlineError }
    func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws { throw offlineError }
}

private struct DemoFailingProgramRepository: ProgramRepository {
    func get(_ id: Identifier<Program>) async throws -> Program? { throw offlineError }
    func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] { throw offlineError }
    func upsert(_ program: Program) async throws -> Program { throw offlineError }
    func delete(_ id: Identifier<Program>) async throws { throw offlineError }
    func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment { throw offlineError }
    func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] { throw offlineError }
}

private struct DemoFailingSessionRepository: SessionRepository {
    func get(_ id: Identifier<Session>) async throws -> Session? { throw offlineError }
    func upsert(_ session: Session) async throws -> Session { throw offlineError }
    func delete(_ id: Identifier<Session>) async throws { throw offlineError }
    func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] { throw offlineError }
    func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        AsyncStream { $0.finish() }
    }
}

private struct DemoFailingProgressRepository: ProgressRepository {
    func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry? { throw offlineError }
    func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry { throw offlineError }
    func delete(_ id: Identifier<ProgressEntry>) async throws { throw offlineError }
    func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] { throw offlineError }
    func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry] { throw offlineError }
    func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]> {
        AsyncStream { $0.finish() }
    }
}

private struct DemoFailingProgressPhotoRepository: ProgressPhotoRepository {
    func get(_ id: Identifier<ProgressPhoto>) async throws -> ProgressPhoto? { throw offlineError }
    func upsert(_ photo: ProgressPhoto) async throws -> ProgressPhoto { throw offlineError }
    func delete(_ id: Identifier<ProgressPhoto>) async throws { throw offlineError }
    func fetchPhotos(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto] { throw offlineError }
    func photos(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressPhoto]> {
        AsyncStream { $0.finish() }
    }
}

private struct DemoFailingPaymentRepository: PaymentRepository {
    func get(_ id: Identifier<Payment>) async throws -> Payment? { throw offlineError }
    func upsert(_ payment: Payment) async throws -> Payment { throw offlineError }
    func delete(_ id: Identifier<Payment>) async throws { throw offlineError }
    func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment] { throw offlineError }
}

private struct DemoFailingPaymentGateway: PaymentGateway {
    func charge(engagementID: Identifier<Engagement>, amountCents: Int, currency: String) async throws -> Payment {
        throw offlineError
    }
    func refund(paymentID: Identifier<Payment>) async throws -> Payment { throw offlineError }
}

private struct DemoFailingMessageRepository: MessageRepository {
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> {
        AsyncStream { $0.finish() }
    }
    func send(_ message: Message) async throws { throw offlineError }
}

private struct DemoFailingOutcomeRepository: OutcomeRepository {
    func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] { throw offlineError }
    func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] { throw offlineError }
}

private struct DemoFailingNotesRepository: NotesRepository {
    func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote] { throw offlineError }
    func upsert(_ note: CoachNote) async throws -> CoachNote { throw offlineError }
    func delete(_ id: Identifier<CoachNote>) async throws { throw offlineError }
}

private struct DemoFailingAvailabilityRepository: AvailabilityRepository {
    func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow] { throw offlineError }
    func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow { throw offlineError }
    func delete(_ id: Identifier<AvailabilityWindow>) async throws { throw offlineError }
}

private struct DemoFailingInviteRepository: InviteRepository {
    func createInvite(forProfessional professionalID: Identifier<Person>, suggestedClientName: String?) async throws -> EngagementInvite {
        throw offlineError
    }
    func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite] { throw offlineError }
    func revokeInvite(_ id: Identifier<EngagementInvite>) async throws { throw offlineError }
    func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement { throw offlineError }
}

#endif
