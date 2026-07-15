#if DEBUG

/// The demo harness's named `Backend` fixtures (see docs/TESTABILITY.md).
/// Each case is built by `DemoScenarioFactory` using only `Backend` protocol
/// calls, never `InMemoryBackend` internals, so scenario construction stays
/// as portable as the rest of the composition root.
enum DemoScenario: String, CaseIterable, Identifiable, Sendable {
    case richDemo
    case showcase
    case emptyCoach
    case errorStates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .richDemo: "Rich demo"
        case .showcase: "Showcase"
        case .emptyCoach: "Brand-new coach"
        case .errorStates: "Error states"
        }
    }

    var subtitle: String {
        switch self {
        case .richDemo:
            "The default seeded backend: 8 clients across every engagement status, verified outcomes, messages, and payments."
        case .showcase:
            "Guarantees one of every important state: a verified outcome, consent on and off, an empty client, " +
                "a refunded payment, upcoming + past sessions, and unread messages."
        case .emptyCoach:
            "A freshly signed-up coach with no clients, programs, or sessions yet — every screen's empty state."
        case .errorStates:
            "Every repository read/write fails — every screen's error banner and retry action."
        }
    }
}

#endif
