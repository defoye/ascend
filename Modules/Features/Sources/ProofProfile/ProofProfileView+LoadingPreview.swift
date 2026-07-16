import DataInterfaces
import Domain
import SwiftUI

/// Forces `ProofProfileView`'s loading-skeleton state for review, without
/// adding a preview-only knob to `ProofProfileViewModel`'s public API:
/// `load()` awaits `professionals.profile(forProfessional:)` first, which
/// this backend never resolves, so `isLoading` stays `true` for the life of
/// the preview (see docs/design/handoff/HANDOFF_README.md §06 "Loading").
struct ProofProfileLoadingPreview: View {
    var body: some View {
        let professionalID = Identifier<Person>()
        let base = PreviewBackend(professionalID: professionalID)
        let backend = HangingProfessionalProfileBackend(base: base)
        NavigationStack {
            ProofProfileView(
                viewModel: ProofProfileViewModel(backend: backend, professionalID: professionalID, paymentsMode: .live)
            )
        }
    }
}

private struct HangingProfessionalProfileBackend: Backend {
    let base: any Backend
    var people: any PersonRepository { base.people }
    var professionals: any ProfessionalRepository { HangingProfessionalRepository(base: base.professionals) }
    var engagements: any EngagementRepository { base.engagements }
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

private struct HangingProfessionalRepository: ProfessionalRepository {
    let base: any ProfessionalRepository
    func get(_ id: Identifier<ProfessionalProfile>) async throws -> ProfessionalProfile? { try await base.get(id) }
    func profile(forProfessional personID: Identifier<Person>) async throws -> ProfessionalProfile? {
        try await Task.sleep(nanoseconds: .max)
        return nil
    }
    func listProfiles() async throws -> [ProfessionalProfile] { try await base.listProfiles() }
    func upsert(_ profile: ProfessionalProfile) async throws -> ProfessionalProfile { try await base.upsert(profile) }
    func delete(_ id: Identifier<ProfessionalProfile>) async throws { try await base.delete(id) }
}

#Preview("ProofProfileView - Loading - Light") {
    ProofProfileLoadingPreview()
        .preferredColorScheme(.light)
}

#Preview("ProofProfileView - Loading - Dark") {
    ProofProfileLoadingPreview()
        .preferredColorScheme(.dark)
}
