import Domain
import Testing
@testable import Features

@Suite("SessionTransitions")
struct SessionTransitionsTests {
    @Test("from .scheduled, exactly completed/cancelled/noShow are allowed")
    func scheduledAllowsTerminalTransitions() {
        let allowed = SessionTransitions.allowed(from: .scheduled)
        #expect(allowed == [.completed, .cancelled, .noShow])
    }

    @Test("terminal statuses allow no further transitions", arguments: [SessionStatus.completed, .cancelled, .noShow])
    func terminalStatusesAreDeadEnds(status: SessionStatus) {
        #expect(SessionTransitions.allowed(from: status).isEmpty)
    }

    @Test("canTransition matches allowed(from:)")
    func canTransitionMatchesAllowed() {
        #expect(SessionTransitions.canTransition(from: .scheduled, to: .completed))
        #expect(SessionTransitions.canTransition(from: .scheduled, to: .cancelled))
        #expect(SessionTransitions.canTransition(from: .scheduled, to: .noShow))
        #expect(!SessionTransitions.canTransition(from: .scheduled, to: .scheduled))
        #expect(!SessionTransitions.canTransition(from: .completed, to: .scheduled))
        #expect(!SessionTransitions.canTransition(from: .cancelled, to: .completed))
        #expect(!SessionTransitions.canTransition(from: .noShow, to: .completed))
    }
}
