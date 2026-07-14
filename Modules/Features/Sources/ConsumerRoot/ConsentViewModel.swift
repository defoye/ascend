import DataInterfaces
import Domain
import Observation

/// View model for the client-facing outcome-sharing consent screen: whether
/// this engagement's progress may be used to derive a `VerifiedOutcome` (see
/// docs/DATA_MODEL.md's `VerificationBasis.consentGranted` pillar).
///
/// Deliberately distinct from photo-sharing consent
/// (`EngagementRepository.photoConsent(for:)`/`setPhotoConsent(_:for:)`,
/// see `ProgressViewModel`) — this is the outcome-derivation grant
/// (`consent(for:)`/`setConsent(_:for:)`), Invariant 1's consent pillar.
/// Toggling it here writes straight through the same repository the coach's
/// `OutcomeRepository` reads, so flipping it off/on genuinely changes
/// whether `Domain.VerifiedOutcome.derive` can yield an outcome for this
/// engagement — not merely a display flag.
@MainActor
@Observable
public final class ConsentViewModel {
    public private(set) var isGranted = false
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public let backend: any Backend
    public let engagementID: Identifier<Engagement>

    public init(backend: any Backend, engagementID: Identifier<Engagement>) {
        self.backend = backend
        self.engagementID = engagementID
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            isGranted = try await backend.engagements.consent(for: engagementID)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your sharing settings. Try again."
        }
    }

    /// Grants or revokes outcome-derivation consent. Writes through
    /// `EngagementRepository.setConsent(_:for:)` before updating local
    /// state, so a failed write never shows a toggle position the backend
    /// doesn't actually hold.
    public func setGranted(_ granted: Bool) async {
        do {
            try await backend.engagements.setConsent(granted, for: engagementID)
            isGranted = granted
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't update your sharing settings. Try again."
        }
    }
}
