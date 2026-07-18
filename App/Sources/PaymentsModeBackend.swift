import DataInterfaces

/// A `Backend` decorator that swaps in `NoOpPaymentGateway` when
/// `PaymentsMode` is `.free`, and forwards every other repository straight
/// through to `wrapped` unchanged.
///
/// This is the composition root's half of Option B (see docs/BACKEND.md
/// "PaymentsMode: free-first rollout"):
/// `AppContainer` wraps whichever concrete backend it builds
/// (`InMemoryStore` today, a future `SupabaseBackend`) in this decorator, so
/// flipping `AppContainer.paymentsMode` from `.free` to `.live` is the only
/// change needed to restore the wrapped backend's real payment gateway —
/// every repository read/write (including `outcomes`, which still only ever
/// derives a `VerifiedOutcome` via `Domain.VerifiedOutcome.derive`) is
/// untouched either way.
struct PaymentsModeBackend: Backend {
    let wrapped: any Backend
    let paymentsMode: PaymentsMode

    var people: any PersonRepository { wrapped.people }
    var professionals: any ProfessionalRepository { wrapped.professionals }
    var engagements: any EngagementRepository { wrapped.engagements }
    var programs: any ProgramRepository { wrapped.programs }
    var sessions: any SessionRepository { wrapped.sessions }
    var progress: any ProgressRepository { wrapped.progress }
    var progressPhotos: any ProgressPhotoRepository { wrapped.progressPhotos }
    var payments: any PaymentRepository { wrapped.payments }
    var messages: any MessageRepository { wrapped.messages }
    var outcomes: any OutcomeRepository { wrapped.outcomes }
    var notes: any NotesRepository { wrapped.notes }
    var availability: any AvailabilityRepository { wrapped.availability }
    var invites: any InviteRepository { wrapped.invites }
    var auth: any AuthGateway { wrapped.auth }
    var analytics: any AnalyticsTracking { wrapped.analytics }
    var deviceTokens: any DeviceTokenRepository { wrapped.deviceTokens }

    /// The one branch point: `.free` never wires a working gateway,
    /// `.live` hands back exactly what the wrapped backend vends (mock
    /// today, a future Stripe-backed adapter later).
    var paymentGateway: any PaymentGateway {
        switch paymentsMode {
        case .free: NoOpPaymentGateway()
        case .live: wrapped.paymentGateway
        }
    }
}
