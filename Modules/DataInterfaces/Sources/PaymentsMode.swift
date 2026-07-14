/// Whether live payments are turned on for this build — the composition
/// root's single switch for the "free first, monetize later" rollout (see
/// docs/BUILD_STATUS.md "Rollout strategy — free first, monetize later").
///
/// Lives in `DataInterfaces` (alongside `PaymentGateway` and `AuthState`, its
/// closest precedent) rather than `Domain`, because it is seam/config — it
/// describes which adapter the composition root wired in, not a fact about
/// the coaching domain — and both `Features` and the App composition root
/// already depend on `DataInterfaces`, so this single enum is visible
/// everywhere it needs to be without either side depending on a concrete
/// backend.
///
/// `.free` is the default: no live payment flows ship, and `Domain.VerifiedOutcome`
/// (which requires a `.succeeded` payment as one of its four pillars — see
/// docs/DATA_MODEL.md) legitimately never derives. Rather than lose the
/// verification "moat" during the free phase, `Features` surfaces the same
/// non-payment pillars as a separate, honestly-labeled "Tracked results"
/// journey — never a `VerifiedOutcome` (Option B). Flipping to `.live` is a
/// single-line change at the composition root (`App/Sources/AppContainer.swift`):
/// it swaps in the real payment gateway and Proof Profile's "Verified"
/// badge activates.
public enum PaymentsMode: String, Sendable, Equatable, Hashable, CaseIterable, Codable {
    /// No live payments: charge/pay/revenue UI is hidden or disabled, and
    /// outcomes surface as "Tracked results", never "Verified".
    case free
    /// Live payments: the charge/pay/revenue UI is active, and
    /// `Domain.VerifiedOutcome`-backed "Verified journeys" surface normally.
    case live
}
