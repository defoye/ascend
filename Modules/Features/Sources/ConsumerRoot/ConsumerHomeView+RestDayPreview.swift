import DataInterfaces
import Domain
import Foundation
import SwiftUI

/// Forces `ConsumerHomeView`'s rest-day empty state for review: overrides
/// `PreviewBackend`'s program assignment with one whose current week has no
/// workouts (a deliberate rest week within an otherwise-active program —
/// the only way "nothing assigned today" arises in this domain model, since
/// `ConsumerProgramSummaries.currentWorkout` returns `nil` exactly when the
/// chosen week's workout list is empty), and seeds a handful of same-day
/// sessions so the "This week" mini progress card also has real data to
/// show (see docs/design/handoff/HANDOFF_README.md §04 "Empty rest-day").
struct ConsumerHomeRestDayPreview: View {
    var body: some View {
        let base = PreviewBackend(professionalID: Identifier<Person>())
        let backend = RestDayBackend(base: base, engagementID: base.engagementAID, now: Date())
        NavigationStack {
            ConsumerHomeView(
                viewModel: ConsumerHomeViewModel(backend: backend, clientID: base.clientAID),
                backend: backend
            )
        }
    }
}

private struct RestDayBackend: Backend {
    let base: any Backend
    let engagementID: Identifier<Engagement>
    let now: Date

    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { base.professionals }
    var engagements: any EngagementRepository { base.engagements }
    var programs: any ProgramRepository { RestDayProgramRepository(engagementID: engagementID) }
    var sessions: any SessionRepository { RestDaySessionRepository(base: base.sessions, engagementID: engagementID, now: now) }
    var progress: any ProgressRepository { base.progress }
    var progressPhotos: any ProgressPhotoRepository { base.progressPhotos }
    var payments: any PaymentRepository { base.payments }
    var paymentGateway: any PaymentGateway { base.paymentGateway }
    var messages: any MessageRepository { base.messages }
    var outcomes: any OutcomeRepository { base.outcomes }
    var notes: any NotesRepository { base.notes }
    var availability: any AvailabilityRepository { base.availability }
    var invites: any InviteRepository { base.invites }
    var auth: any AuthGateway { base.auth }
    var analytics: any AnalyticsTracking { base.analytics }
}

/// A program with one assigned week whose `workouts` list is empty — a
/// legitimate, un-fabricated "rest week" state the real domain model
/// already supports (`ProgramWeek.workouts: [Workout]` has no non-empty
/// invariant).
private struct RestDayProgramRepository: ProgramRepository {
    let engagementID: Identifier<Engagement>
    private let program: Program
    private let assignment: ProgramAssignment

    init(engagementID: Identifier<Engagement>) {
        self.engagementID = engagementID
        let programID = Identifier<Program>()
        program = Program(
            id: programID,
            authorID: Identifier(),
            title: "Fat Loss Kickstart",
            summary: "A 6-week full-body circuit program with a programmed deload week.",
            weeks: [ProgramWeek(id: Identifier(), index: 0, workouts: [])]
        )
        assignment = ProgramAssignment(id: Identifier(), programID: programID, engagementID: engagementID, assignedAt: Date(), startDate: Date())
    }

    func get(_ id: Identifier<Program>) async throws -> Program? { id == program.id ? program : nil }
    func list(forAuthor authorID: Identifier<Person>) async throws -> [Program] { [] }
    func upsert(_ program: Program) async throws -> Program { program }
    func delete(_ id: Identifier<Program>) async throws {}
    func assign(_ assignment: ProgramAssignment) async throws -> ProgramAssignment { assignment }
    func assignments(forEngagement engagementID: Identifier<Engagement>) async throws -> [ProgramAssignment] {
        engagementID == self.engagementID ? [assignment] : []
    }
}

/// Same-day session offsets only (never multi-day) so the "this calendar
/// week" bucket `ConsumerProgramSummaries.weeklySessionSummary` reads never
/// risks crossing a week boundary depending on when the preview renders.
private struct RestDaySessionRepository: SessionRepository {
    let base: any SessionRepository
    let engagementID: Identifier<Engagement>
    let now: Date

    func get(_ id: Identifier<Session>) async throws -> Session? { try await base.get(id) }
    func upsert(_ session: Session) async throws -> Session { try await base.upsert(session) }
    func delete(_ id: Identifier<Session>) async throws { try await base.delete(id) }
    func fetchSessions(forEngagement engagementID: Identifier<Engagement>) async throws -> [Session] {
        guard engagementID == self.engagementID else { return try await base.fetchSessions(forEngagement: engagementID) }
        return [
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-5 * 3_600), status: .completed),
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-3 * 3_600), status: .completed),
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(-1 * 3_600), status: .completed),
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(2 * 3_600), status: .scheduled),
            Session(id: Identifier(), engagementID: engagementID, scheduledAt: now.addingTimeInterval(4 * 3_600), status: .scheduled)
        ]
    }
    func sessions(forEngagement engagementID: Identifier<Engagement>) -> AsyncStream<[Session]> {
        base.sessions(forEngagement: engagementID)
    }
}
