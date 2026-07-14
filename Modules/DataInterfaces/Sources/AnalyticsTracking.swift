import Domain

/// A single analytics/crash-context event.
///
/// Every case carries only identifiers and enum values — **never** a display
/// name, a message body, a note body, or a photo reference. This is a hard
/// invariant, not a style preference: `AnalyticsEventTests` (see
/// `FeaturesTests`) asserts none of these cases can carry a `String`
/// associated value at all, so a future case that tries to smuggle in PII
/// (e.g. a client's name) fails to compile against that shape rather than
/// merely failing a lint pass.
public enum AnalyticsEvent: Sendable, Equatable {
    case screenViewed(Screen)
    case sessionBooked(engagementID: Identifier<Engagement>)
    case sessionStatusChanged(sessionID: Identifier<Session>, status: SessionStatus)
    case progressLogged(engagementID: Identifier<Engagement>, metric: MetricKind)
    case programAssigned(engagementID: Identifier<Engagement>)
    case paymentCharged(engagementID: Identifier<Engagement>)
    case consentChanged(engagementID: Identifier<Engagement>, granted: Bool)
    case photoConsentChanged(engagementID: Identifier<Engagement>, granted: Bool)
    case accountDeletionRequested(personID: Identifier<Person>)
    case accountDeleted(personID: Identifier<Person>)
    case errorOccurred(context: ErrorContext)

    /// A named screen, for lightweight view tracking. Deliberately an enum
    /// (not a free-text screen name) so no call site can accidentally pass
    /// something identifying.
    public enum Screen: String, Sendable, Equatable, CaseIterable {
        case today, clients, clientDetail, programs, programBuilder, schedule
        case messages, messageThread, progress, proofProfile, settings
        case consumerHome, consumerProgress, consumerMe, consent, onboarding
    }

    /// Where a surfaced (non-fatal, handled) error occurred, for aggregate
    /// error-rate monitoring without logging the error's message text
    /// (which could echo back user-entered content).
    public enum ErrorContext: String, Sendable, Equatable, CaseIterable {
        case loadDashboard, loadClients, loadClientDetail, loadPrograms, loadSchedule
        case loadMessages, loadProgress, loadProofProfile, loadSettings
        case bookSession, updateSessionStatus, logProgress, assignProgram
        case chargePayment, updateConsent, deleteAccount
    }
}

/// A mockable seam for analytics/crash reporting, vended by `Backend` (the
/// same seam pattern as every repository — see docs/ARCHITECTURE.md).
/// `Features` code only ever depends on this protocol, never a concrete
/// analytics SDK.
public protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
}

/// The production default: discards every event. A real build would swap
/// this for a concrete provider at the composition root (the `Ascend` App
/// target) without any `Features` code changing — see docs/BACKEND.md.
public struct NoOpAnalyticsTracker: AnalyticsTracking {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
}
