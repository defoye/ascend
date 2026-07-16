import DataInterfaces
import Domain
import Foundation
import Supabase

/// The production `Backend` adapter (see docs/ARCHITECTURE.md,
/// docs/BACKEND.md): implements every `DataInterfaces` repository protocol
/// plus `AuthGateway` against real Supabase Postgres tables, Auth, Storage,
/// and Realtime. The `Ascend` App target's composition root
/// (`App/Sources/AppContainer.swift`) is the only place this type is
/// constructed — see docs/ARCHITECTURE.md's "composition root is the only
/// place a concrete backend is selected."
///
/// A plain `struct` (not an actor, unlike `InMemoryBackend`): there is no
/// local mutable state to protect here — every repository read/write goes
/// straight to Postgres — except the offline-write queue, which is itself an
/// actor (`OfflineWriteQueue`) and therefore safe to share as a `let`.
public struct SupabaseBackend: Backend, Sendable {
    let client: SupabaseClient
    let queue: OfflineWriteQueue

    /// The `JSONEncoder`/`JSONDecoder` every Row DTO in this module encodes/decodes
    /// with — both for direct PostgREST request bodies (the SDK uses these as its
    /// own defaults, see `PostgrestClient.Configuration`) and for this module's own
    /// manual encode/decode calls (queue payload persistence/replay), so a row's
    /// on-the-wire shape and its queued-on-disk shape always agree.
    static let jsonEncoder = PostgrestClient.Configuration.jsonEncoder
    static let jsonDecoder = PostgrestClient.Configuration.jsonDecoder

    /// - Parameters:
    ///   - supabaseURL: The project URL (`SUPABASE_URL`, e.g.
    ///     `https://xxxx.supabase.co`) — see docs/BACKEND.md and the
    ///     composition root's `SupabaseConfig` for how this is read from
    ///     `Config/Secrets.xcconfig` via Info.plist substitution.
    ///   - supabaseKey: The client-safe publishable/anon key
    ///     (`SUPABASE_ANON_KEY`) — never the `service_role` secret key.
    ///   - queue: Injectable for tests; defaults to the real disk-backed queue.
    public init(supabaseURL: URL, supabaseKey: String, queue: OfflineWriteQueue = OfflineWriteQueue()) {
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        self.queue = queue
    }

    // MARK: - Backend

    public var people: any PersonRepository { self }
    public var professionals: any ProfessionalRepository { self }
    public var engagements: any EngagementRepository { self }
    public var programs: any ProgramRepository { self }
    public var sessions: any SessionRepository { self }
    public var progress: any ProgressRepository { self }
    public var progressPhotos: any ProgressPhotoRepository { self }
    public var payments: any PaymentRepository { self }
    /// The real Stripe-backed gateway lands with Prompt 14 (Stripe Connect
    /// Express via Supabase Edge Functions — see docs/BACKEND.md). Until
    /// then, a live-mode charge against `SupabaseBackend` must throw rather
    /// than fabricate a `.succeeded` `Payment` row — see docs/BUILD_STATUS.md
    /// "Rollout strategy — free first, monetize later" (in practice launch
    /// ships with `PaymentsMode.free`, so `PaymentsModeBackend` substitutes
    /// `NoOpPaymentGateway` ahead of this ever being reached anyway).
    public var paymentGateway: any PaymentGateway { NoOpPaymentGateway() }
    public var messages: any MessageRepository { self }
    public var outcomes: any OutcomeRepository { self }
    public var notes: any NotesRepository { self }
    public var availability: any AvailabilityRepository { self }
    public var invites: any InviteRepository { self }
    public var auth: any AuthGateway { self }
    public var deviceTokens: any DeviceTokenRepository { self }
    /// No production analytics provider is wired up yet (see docs/ROADMAP.md);
    /// this keeps `Backend.analytics` total without pulling in a concrete SDK.
    /// Swapping this for a real provider is a one-line change here, exactly
    /// like every other seam.
    public var analytics: any AnalyticsTracking { NoOpAnalyticsTracker() }
}
