import DataInterfaces
import Domain
import SwiftUI

/// Forces `ConsumerHomeView`'s loading-skeleton state for review, without
/// adding a preview-only knob to `ConsumerHomeViewModel`'s public API:
/// `load()` awaits `engagements.fetchEngagements(forClient:)`, which this
/// backend never resolves, so `isLoading` stays `true` for the life of the
/// preview (mirrors `TodayView.swift`'s `HangingEngagementsBackend`; see
/// docs/design/handoff/HANDOFF_README.md §04 "Loading skeleton").
struct ConsumerHomeLoadingPreview: View {
    var body: some View {
        let base = PreviewBackend(professionalID: Identifier<Person>())
        let backend = HangingClientEngagementsBackend(base: base)
        NavigationStack {
            ConsumerHomeView(
                viewModel: ConsumerHomeViewModel(backend: backend, clientID: base.clientAID),
                backend: backend
            )
        }
    }
}

private struct HangingClientEngagementsBackend: Backend {
    let base: any Backend
    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { base.professionals }
    var engagements: any EngagementRepository { HangingClientEngagementRepository(base: base.engagements) }
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

private struct HangingClientEngagementRepository: EngagementRepository {
    let base: any EngagementRepository
    func get(_ id: Identifier<Engagement>) async throws -> Engagement? { try await base.get(id) }
    func upsert(_ engagement: Engagement) async throws -> Engagement { try await base.upsert(engagement) }
    func delete(_ id: Identifier<Engagement>) async throws { try await base.delete(id) }
    func fetchEngagements(forProfessional professionalID: Identifier<Person>) async throws -> [Engagement] {
        try await base.fetchEngagements(forProfessional: professionalID)
    }
    func engagements(forProfessional professionalID: Identifier<Person>) -> AsyncStream<[Engagement]> {
        base.engagements(forProfessional: professionalID)
    }
    func fetchEngagements(forClient clientID: Identifier<Person>) async throws -> [Engagement] {
        try await Task.sleep(nanoseconds: .max)
        return []
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
