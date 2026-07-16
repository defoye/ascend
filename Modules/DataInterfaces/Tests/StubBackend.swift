import Domain
import Foundation
@testable import DataInterfaces

/// A minimal, no-op stub proving that `DataInterfaces`' protocol shapes compose
/// into a working `Backend` — exercised only at compile time and in a couple of
/// smoke tests here. Real behavior lives in `InMemoryStore`.

struct StubPersonRepository: PersonRepository {
    func get(_ id: Identifier<Person>) async throws -> Person? { nil }
    func list() async throws -> [Person] { [] }
    func upsert(_ person: Person) async throws -> Person { person }
    func delete(_ id: Identifier<Person>) async throws {}
}

struct StubProfessionalRepository: ProfessionalRepository {
    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? { nil }
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? { nil }
    func listProfiles() async throws -> [ProfessionalProfile] { [] }
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile { profile }
    func delete(_ id: Identifier<ProfessionalProfile>) async throws {}
}

struct StubEngagementRepository: EngagementRepository {
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? { nil }
    func upsert(_ engagement: Engagement) async throws -> Engagement { engagement }
    func delete(_ id: Identifier<Engagement>) async throws {}
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] { [] }
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        AsyncStream { $0.finish() }
    }
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] { [] }
    func consent(for engagementID: Identifier<Engagement>) async throws -> Bool { false }
    func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {}
    func photoConsent(for engagementID: Identifier<Engagement>) async throws -> Bool { false }
    func setPhotoConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {}
}

struct StubProgramRepository: ProgramRepository {
    func get(_ id: Identifier<Program>) async throws -> Program? { nil }
    func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] { [] }
    func upsert(_ program: Program) async throws -> Program { program }
    func delete(_ id: Identifier<Program>) async throws {}
    func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment { assignment }
    func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] { [] }
}

struct StubSessionRepository: SessionRepository {
    func get(_ id: Identifier<Session>) async throws -> Session? { nil }
    func upsert(_ session: Session) async throws -> Session { session }
    func delete(_ id: Identifier<Session>) async throws {}
    func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] { [] }
    func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        AsyncStream { $0.finish() }
    }
}

struct StubProgressRepository: ProgressRepository {
    func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry? { nil }
    func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry { entry }
    func delete(_ id: Identifier<ProgressEntry>) async throws {}
    func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] { [] }
    func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry] { [] }
    func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]> {
        AsyncStream { $0.finish() }
    }
}

struct StubProgressPhotoRepository: ProgressPhotoRepository {
    func get(_ id: Identifier<ProgressPhoto>) async throws -> ProgressPhoto? { nil }
    func upsert(_ photo: ProgressPhoto) async throws -> ProgressPhoto { photo }
    func delete(_ id: Identifier<ProgressPhoto>) async throws {}
    func fetchPhotos(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressPhoto] { [] }
    func photos(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressPhoto]> {
        AsyncStream { $0.finish() }
    }
}

struct StubPaymentRepository: PaymentRepository {
    func get(_ id: Identifier<Payment>) async throws -> Payment? { nil }
    func upsert(_ payment: Payment) async throws -> Payment { payment }
    func delete(_ id: Identifier<Payment>) async throws {}
    func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment] { [] }
}

struct StubPaymentGateway: PaymentGateway {
    func charge(engagementID: Identifier<Engagement>, amountCents: Int, currency: String) async throws -> Payment {
        Payment(
            id: Identifier(),
            engagementID: engagementID,
            amountCents: amountCents,
            currency: currency,
            status: .succeeded,
            platformFeeCents: 0,
            stripePaymentIntentID: nil,
            createdAt: Date()
        )
    }

    func refund(paymentID: Identifier<Payment>) async throws -> Payment {
        Payment(
            id: paymentID,
            engagementID: Identifier(),
            amountCents: 0,
            currency: "USD",
            status: .refunded,
            platformFeeCents: 0,
            stripePaymentIntentID: nil,
            createdAt: Date()
        )
    }
}

struct StubMessageRepository: MessageRepository {
    func fetchMessages(forEngagement engagementID: Identifier<Engagement>) async throws -> [Message] { [] }
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> {
        AsyncStream { $0.finish() }
    }
    func send(_ message: Message) async throws {}
}

struct StubOutcomeRepository: OutcomeRepository {
    func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] { [] }
    func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] { [] }
}

struct StubNotesRepository: NotesRepository {
    func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote] { [] }
    func upsert(_ note: CoachNote) async throws -> CoachNote { note }
    func delete(_ id: Identifier<CoachNote>) async throws {}
}

struct StubAvailabilityRepository: AvailabilityRepository {
    func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow] { [] }
    func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow { window }
    func delete(_ id: Identifier<AvailabilityWindow>) async throws {}
}

struct StubInviteRepository: InviteRepository {
    func createInvite(forProfessional professionalID: Identifier<Person>, suggestedClientName: String?) async throws -> EngagementInvite {
        EngagementInvite(
            id: Identifier(),
            code: "STUBCODE",
            professionalID: professionalID,
            suggestedClientName: suggestedClientName,
            createdAt: Date(),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
    }
    func pendingInvites(forProfessional professionalID: Identifier<Person>) async throws -> [EngagementInvite] { [] }
    func revokeInvite(_ id: Identifier<EngagementInvite>) async throws {}
    func claimInvite(code: String, clientID: Identifier<Person>) async throws -> Engagement {
        Engagement(id: Identifier(), clientID: clientID, professionalID: Identifier(), status: .active, startedAt: Date(), endedAt: nil)
    }
}

struct StubAuthGateway: AuthGateway {
    var currentAuth: AsyncStream<AuthState> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
}

struct StubBackend: Backend {
    let people: any PersonRepository = StubPersonRepository()
    let professionals: any ProfessionalRepository = StubProfessionalRepository()
    let engagements: any EngagementRepository = StubEngagementRepository()
    let programs: any ProgramRepository = StubProgramRepository()
    let sessions: any SessionRepository = StubSessionRepository()
    let progress: any ProgressRepository = StubProgressRepository()
    let progressPhotos: any ProgressPhotoRepository = StubProgressPhotoRepository()
    let payments: any PaymentRepository = StubPaymentRepository()
    let paymentGateway: any PaymentGateway = StubPaymentGateway()
    let messages: any MessageRepository = StubMessageRepository()
    let outcomes: any OutcomeRepository = StubOutcomeRepository()
    let notes: any NotesRepository = StubNotesRepository()
    let availability: any AvailabilityRepository = StubAvailabilityRepository()
    let invites: any InviteRepository = StubInviteRepository()
    let auth: any AuthGateway = StubAuthGateway()
    let analytics: any AnalyticsTracking = NoOpAnalyticsTracker()
}
