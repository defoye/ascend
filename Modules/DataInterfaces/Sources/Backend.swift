/// The single seam the App composes against.
///
/// A `Backend` vends every repository protocol plus authentication. Concrete
/// adapters (`InMemoryStore`, and a future `SupabaseBackend`) implement this
/// protocol; `Features` and the composition root depend only on it, never on a
/// concrete adapter (see docs/ARCHITECTURE.md).
public protocol Backend: Sendable {
    var people: any PersonRepository { get }
    var professionals: any ProfessionalRepository { get }
    var engagements: any EngagementRepository { get }
    var programs: any ProgramRepository { get }
    var sessions: any SessionRepository { get }
    var progress: any ProgressRepository { get }
    var progressPhotos: any ProgressPhotoRepository { get }
    var payments: any PaymentRepository { get }
    var paymentGateway: any PaymentGateway { get }
    var messages: any MessageRepository { get }
    var outcomes: any OutcomeRepository { get }
    var notes: any NotesRepository { get }
    var availability: any AvailabilityRepository { get }
    var invites: any InviteRepository { get }
    var auth: any AuthGateway { get }
    var analytics: any AnalyticsTracking { get }
    var deviceTokens: any DeviceTokenRepository { get }
}

/// Default `deviceTokens` so every existing `Backend` conformer (preview/test
/// stubs included) keeps compiling without implementing this repository —
/// mirrors how `NoOpPaymentGateway` lets `SupabaseBackend` opt out of a real
/// gateway until it has one. Adapters that back push notifications for real
/// (`InMemoryBackend`, `SupabaseBackend`) override this with their own
/// conformance instead of relying on the default.
public extension Backend {
    var deviceTokens: any DeviceTokenRepository { NoOpDeviceTokenRepository() }
}
