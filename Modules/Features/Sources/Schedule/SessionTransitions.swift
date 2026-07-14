import Domain

/// The valid lifecycle transitions for a `Session`'s `SessionStatus`,
/// factored out as a pure, directly-testable rule (see docs/DATA_MODEL.md
/// "Engagement & sessions"). A session is booked directly into `.scheduled`
/// (there is no separate "confirmed" state — scheduling a session **is** the
/// confirmation step); from there it may be completed, cancelled, or marked
/// a no-show. Every other status is terminal.
public enum SessionTransitions {
    /// The set of statuses a session in `status` may transition to. Empty
    /// for every terminal status (`.completed`, `.cancelled`, `.noShow`).
    public static func allowed(from status: SessionStatus) -> Set<SessionStatus> {
        switch status {
        case .scheduled:
            [.completed, .cancelled, .noShow]
        case .completed, .cancelled, .noShow:
            []
        }
    }

    /// Whether moving from `from` to `to` is a valid transition.
    public static func canTransition(from: SessionStatus, to: SessionStatus) -> Bool {
        allowed(from: from).contains(to)
    }
}
