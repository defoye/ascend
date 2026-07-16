import DataInterfaces
import Domain
import SwiftUI

/// Forces `ClientDetailView`'s loading-skeleton state for review, without
/// adding a preview-only knob to `ClientDetailViewModel`'s public API:
/// `load()` awaits `engagements.get(_:)`, which this backend never resolves,
/// so `isLoading` stays `true` for the life of the preview (see
/// docs/design/handoff/HANDOFF_README.md §02 "Loading").
struct ClientDetailLoadingPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let base = PreviewBackend(professionalID: professionalID)
        let backend = HangingEngagementGetBackend(base: base)
        NavigationStack {
            ClientDetailView(
                viewModel: ClientDetailViewModel(
                    backend: backend,
                    engagementID: base.engagementAID,
                    professionalID: professionalID
                )
            )
        }
    }
}

private struct HangingEngagementGetBackend: Backend {
    let base: any Backend
    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { base.professionals }
    var engagements: any EngagementRepository { HangingGetEngagementRepository(base: base.engagements) }
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
    var invites: any InviteRepository { base.invites }
    var auth: any AuthGateway { base.auth }
    var analytics: any AnalyticsTracking { base.analytics }
}

private struct HangingGetEngagementRepository: EngagementRepository {
    let base: any EngagementRepository
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? {
        try await Task.sleep(nanoseconds: .max)
        return nil
    }
    func upsert(_ engagement: Engagement) async throws -> Engagement { try await base.upsert(engagement) }
    func delete(_ id: Identifier<Engagement>) async throws { try await base.delete(id) }
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        try await base.fetchEngagements(forProfessional: professionalID)
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
