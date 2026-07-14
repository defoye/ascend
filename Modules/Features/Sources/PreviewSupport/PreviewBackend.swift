import DataInterfaces
import Domain
import Foundation

/// A hand-rolled, in-process `Backend` used only by `#Preview`s in this
/// module. `Features` may never import a concrete backend adapter like
/// `InMemoryStore` (see docs/ARCHITECTURE.md), so previews of
/// backend-dependent screens compose this tiny fixture instead of
/// `InMemoryStore.seeded()`.
struct PreviewBackend: Backend {
    let professionalID: Identifier<Person>
    private let clientA = Identifier<Person>()
    private let clientB = Identifier<Person>()
    private let engagementA: Identifier<Engagement>
    private let engagementB: Identifier<Engagement>

    private let peopleByID: [Identifier<Person>: Person]
    private let engagementsList: [Engagement]
    private let sessionsByEngagement: [Identifier<Engagement>: [Session]]
    private let progressByEngagement: [Identifier<Engagement>: [ProgressEntry]]
    private let paymentsByEngagement: [Identifier<Engagement>: [Payment]]
    private let messagesByEngagement: [Identifier<Engagement>: [Message]]
    private let notesByEngagement: [Identifier<Engagement>: [CoachNote]]
    private let programsByID: [Identifier<Program>: Program]
    private let assignmentsByEngagement: [Identifier<Engagement>: [ProgramAssignment]]

    /// Exposed so previews of screens that need a concrete engagement (e.g.
    /// `ClientDetailView`) can reference this fixture's primary engagement.
    var engagementAID: Identifier<Engagement> { engagementA }

    init(professionalID: Identifier<Person> = Identifier()) {
        self.professionalID = professionalID
        let engagementA = Identifier<Engagement>()
        let engagementB = Identifier<Engagement>()
        self.engagementA = engagementA
        self.engagementB = engagementB

        let now = Date()
        let clientA = self.clientA
        let clientB = self.clientB

        peopleByID = Self.makePeople(clientA: clientA, clientB: clientB)
        engagementsList = Self.makeEngagements(
            engagementA: engagementA, engagementB: engagementB,
            clientA: clientA, clientB: clientB,
            professionalID: professionalID, now: now
        )
        sessionsByEngagement = Self.makeSessions(engagementA: engagementA, engagementB: engagementB, now: now)
        progressByEngagement = Self.makeProgress(engagementA: engagementA, now: now)
        paymentsByEngagement = Self.makePayments(engagementA: engagementA, engagementB: engagementB, now: now)
        messagesByEngagement = Self.makeMessages(engagementB: engagementB, clientB: clientB, now: now)
        notesByEngagement = Self.makeNotes(engagementA: engagementA, professionalID: professionalID, now: now)
        let strengthProgramID = Identifier<Program>()
        programsByID = Self.makePrograms(professionalID: professionalID, strengthProgramID: strengthProgramID)
        assignmentsByEngagement = Self.makeAssignments(engagementA: engagementA, programID: strengthProgramID, now: now)
    }

    // MARK: - Fixture factories

    private static func makePeople(clientA: Identifier<Person>, clientB: Identifier<Person>) -> [Identifier<Person>: Person] {
        [
            clientA: Person(id: clientA, displayName: "Morgan Chen", roles: [.consumer], goals: []),
            clientB: Person(id: clientB, displayName: "Sam Patel", roles: [.consumer], goals: [])
        ]
    }

    // swiftlint:disable:next function_parameter_count
    private static func makeEngagements(
        engagementA: Identifier<Engagement>,
        engagementB: Identifier<Engagement>,
        clientA: Identifier<Person>,
        clientB: Identifier<Person>,
        professionalID: Identifier<Person>,
        now: Date
    ) -> [Engagement] {
        [
            Engagement(
                id: engagementA,
                clientID: clientA,
                professionalID: professionalID,
                status: .active,
                startedAt: now.addingTimeInterval(-60 * 86_400),
                endedAt: nil
            ),
            Engagement(
                id: engagementB,
                clientID: clientB,
                professionalID: professionalID,
                status: .active,
                startedAt: now.addingTimeInterval(-40 * 86_400),
                endedAt: nil
            )
        ]
    }

    private static func makeSessions(
        engagementA: Identifier<Engagement>,
        engagementB: Identifier<Engagement>,
        now: Date
    ) -> [Identifier<Engagement>: [Session]] {
        [
            engagementA: [
                Session(id: Identifier(), engagementID: engagementA, scheduledAt: now.addingTimeInterval(2 * 86_400), status: .scheduled)
            ],
            engagementB: [
                Session(id: Identifier(), engagementID: engagementB, scheduledAt: now.addingTimeInterval(5 * 86_400), status: .scheduled)
            ]
        ]
    }

    private static func makeProgress(
        engagementA: Identifier<Engagement>,
        now: Date
    ) -> [Identifier<Engagement>: [ProgressEntry]] {
        [
            engagementA: [
                ProgressEntry(
                    id: Identifier(),
                    engagementID: engagementA,
                    metric: .bodyweight,
                    value: MetricValue(value: 196, unit: .lb),
                    recordedAt: now.addingTimeInterval(-1 * 86_400),
                    source: .clientSelfReported
                )
            ]
        ]
    }

    private static func makePayments(
        engagementA: Identifier<Engagement>,
        engagementB: Identifier<Engagement>,
        now: Date
    ) -> [Identifier<Engagement>: [Payment]] {
        [
            engagementA: [
                Payment(
                    id: Identifier(),
                    engagementID: engagementA,
                    amountCents: 12_000,
                    currency: "USD",
                    status: .succeeded,
                    platformFeeCents: 1_200,
                    stripePaymentIntentID: "pi_preview_a",
                    createdAt: now.addingTimeInterval(-5 * 86_400)
                )
            ],
            engagementB: [
                Payment(
                    id: Identifier(),
                    engagementID: engagementB,
                    amountCents: 15_000,
                    currency: "USD",
                    status: .succeeded,
                    platformFeeCents: 1_500,
                    stripePaymentIntentID: "pi_preview_b",
                    createdAt: now.addingTimeInterval(-10 * 86_400)
                )
            ]
        ]
    }

    private static func makeMessages(
        engagementB: Identifier<Engagement>,
        clientB: Identifier<Person>,
        now: Date
    ) -> [Identifier<Engagement>: [Message]] {
        [
            engagementB: [
                Message(
                    id: Identifier(),
                    engagementID: engagementB,
                    authorID: clientB,
                    body: "New squat max today: 225!",
                    sentAt: now.addingTimeInterval(-2 * 3_600)
                )
            ]
        ]
    }

    private static func makeNotes(
        engagementA: Identifier<Engagement>,
        professionalID: Identifier<Person>,
        now: Date
    ) -> [Identifier<Engagement>: [CoachNote]] {
        [
            engagementA: [
                CoachNote(
                    id: Identifier(),
                    engagementID: engagementA,
                    authorID: professionalID,
                    body: "Responds well to weekly check-ins.",
                    createdAt: now.addingTimeInterval(-10 * 86_400),
                    updatedAt: now.addingTimeInterval(-10 * 86_400)
                )
            ]
        ]
    }

    var people: any PersonRepository { PreviewPersonRepository(peopleByID: peopleByID) }
    var professionals: any ProfessionalRepository { PreviewProfessionalRepository() }
    var engagements: any EngagementRepository { PreviewEngagementRepository(engagements: engagementsList) }
    var programs: any ProgramRepository {
        PreviewProgramRepository(programsByID: programsByID, assignmentsByEngagement: assignmentsByEngagement)
    }
    var sessions: any SessionRepository { PreviewSessionRepository(sessionsByEngagement: sessionsByEngagement) }
    var progress: any ProgressRepository { PreviewProgressRepository(progressByEngagement: progressByEngagement) }
    var payments: any PaymentRepository { PreviewPaymentRepository(paymentsByEngagement: paymentsByEngagement) }
    var messages: any MessageRepository { PreviewMessageRepository(messagesByEngagement: messagesByEngagement) }
    var outcomes: any OutcomeRepository { PreviewOutcomeRepository() }
    var notes: any NotesRepository { PreviewNotesRepository(notesByEngagement: notesByEngagement) }
    var auth: any AuthGateway { PreviewAuthGateway() }
}

private struct PreviewPersonRepository: PersonRepository {
    let peopleByID: [Identifier<Person>: Person]
    func get(_ id: Identifier<Person>) async throws -> Person? { peopleByID[id] }
    func list() async throws -> [Person] { Array(peopleByID.values) }
    func upsert(_ person: Person) async throws -> Person { person }
    func delete(_ id: Identifier<Person>) async throws {}
}

private struct PreviewProfessionalRepository: ProfessionalRepository {
    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? { nil }
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? { nil }
    func listProfiles() async throws -> [ProfessionalProfile] { [] }
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile { profile }
    func delete(_ id: Identifier<ProfessionalProfile>) async throws {}
}

private struct PreviewEngagementRepository: EngagementRepository {
    let engagements: [Engagement]
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? { engagements.first { $0.id == id } }
    func upsert(_ engagement: Engagement) async throws -> Engagement { engagement }
    func delete(_ id: Identifier<Engagement>) async throws {}
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] { engagements }
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        AsyncStream { $0.finish() }
    }
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] {
        engagements.filter { $0.clientID == clientID }
    }
    func consent(for engagementID: Identifier<Engagement>) async throws -> Bool { true }
    func setConsent(_ granted: Bool, for engagementID: Identifier<Engagement>) async throws {}
}

private struct PreviewSessionRepository: SessionRepository {
    let sessionsByEngagement: [Identifier<Engagement>: [Session]]
    func get(_ id: Identifier<Session>) async throws -> Session? { nil }
    func upsert(_ session: Session) async throws -> Session { session }
    func delete(_ id: Identifier<Session>) async throws {}
    func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] {
        sessionsByEngagement[engagementID] ?? []
    }
    func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        AsyncStream { $0.finish() }
    }
}

private struct PreviewProgressRepository: ProgressRepository {
    let progressByEngagement: [Identifier<Engagement>: [ProgressEntry]]
    func get(_ id: Identifier<ProgressEntry>) async throws -> ProgressEntry? { nil }
    func upsert(_ entry: ProgressEntry) async throws -> ProgressEntry { entry }
    func delete(_ id: Identifier<ProgressEntry>) async throws {}
    func fetchEntries(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgressEntry] {
        progressByEngagement[engagementID] ?? []
    }
    func fetchEntries(
        forEngagement engagementID: Identifier<Engagement>,
        metric: MetricKind
    ) async throws -> [ProgressEntry] {
        (progressByEngagement[engagementID] ?? []).filter { $0.metric == metric }
    }
    func entries(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[ProgressEntry]> {
        AsyncStream { $0.finish() }
    }
}

private struct PreviewPaymentRepository: PaymentRepository {
    let paymentsByEngagement: [Identifier<Engagement>: [Payment]]
    func get(_ id: Identifier<Payment>) async throws -> Payment? { nil }
    func upsert(_ payment: Payment) async throws -> Payment { payment }
    func delete(_ id: Identifier<Payment>) async throws {}
    func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment] {
        paymentsByEngagement[engagementID] ?? []
    }
}

private struct PreviewMessageRepository: MessageRepository {
    let messagesByEngagement: [Identifier<Engagement>: [Message]]
    func messages(in engagement: Identifier<Engagement>) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            continuation.yield(messagesByEngagement[engagement] ?? [])
            continuation.finish()
        }
    }
    func send(_ message: Message) async throws {}
}

private struct PreviewOutcomeRepository: OutcomeRepository {
    func outcomes(forProfessional professionalID: Identifier<Person>) async throws -> [VerifiedOutcome] { [] }
    func outcomes(forEngagement engagementID: Identifier<Engagement>) async throws -> [VerifiedOutcome] { [] }
}

private struct PreviewNotesRepository: NotesRepository {
    let notesByEngagement: [Identifier<Engagement>: [CoachNote]]
    func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote] {
        notesByEngagement[engagementID] ?? []
    }
    func upsert(_ note: CoachNote) async throws -> CoachNote { note }
    func delete(_ id: Identifier<CoachNote>) async throws {}
}

private struct PreviewAuthGateway: AuthGateway {
    var currentAuth: AsyncStream<AuthState> { AsyncStream { $0.finish() } }
    func signIn(email: String, password: String) async throws {}
    func signUp(email: String, password: String, displayName: String) async throws {}
    func signOut() async throws {}
}
