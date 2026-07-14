import DataInterfaces
import Domain
import Foundation
import Observation

/// A client's self-reported training experience, captured during onboarding
/// intake. Kept as a `Features`-local type (not `Domain`) since
/// docs/DATA_MODEL.md has no field for it yet — the structured intake is
/// persisted as a `Goal` (which the data model does support) plus a
/// human-readable summary message to the coach (see
/// `ConsumerOnboardingViewModel.submit()`), not as a new Domain type.
public enum ExperienceLevel: String, CaseIterable, Sendable, Identifiable {
    case beginner
    case intermediate
    case advanced

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .beginner: "New to training"
        case .intermediate: "Some experience"
        case .advanced: "Experienced"
        }
    }
}

/// View model for the goal-first consumer onboarding intake: goal, self-
/// reported experience level, injuries/limitations, and preferences.
///
/// Per docs/PRODUCT.md's "AI: intentionally deferred, not dropped", this is
/// **not** an AI-assessed intake — it only captures structured data.
/// Consumer<->professional matching on top of it is a later, deliberately
/// deferred phase (see docs/ROADMAP.md AI-2/AI-3).
///
/// `submit()` produces a real `Goal` (per docs/DATA_MODEL.md) appended to
/// the client's `Person.goals` and persisted via
/// `PersonRepository.upsert(_:)` — the one Domain type this intake
/// legitimately maps onto — and, when an engagement already exists, a
/// summary `Message` to the coach so the rest of the structured intake
/// (experience/injuries/preferences) is stored against the relationship
/// too, without inventing new Domain types.
@MainActor
@Observable
public final class ConsumerOnboardingViewModel {
    public var goalKind: GoalKind = .generalHealth
    public var experienceLevel: ExperienceLevel = .beginner
    public var injuriesText = ""
    public var preferencesText = ""
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let clientID: Identifier<Person>
    private let engagementID: Identifier<Engagement>?
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        clientID: Identifier<Person>,
        engagementID: Identifier<Engagement>? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.clientID = clientID
        self.engagementID = engagementID
        self.clock = clock
    }

    /// Builds a `Goal` from the current form state, appends it to the
    /// client's `Person.goals`, persists the updated person, and (when an
    /// engagement is known) sends the coach a summary message capturing the
    /// rest of the intake. Returns the newly created `Goal` on success.
    @discardableResult
    public func submit() async -> Goal? {
        isSaving = true
        defer { isSaving = false }

        guard let person = try? await backend.people.get(clientID) else {
            saveErrorMessage = "Couldn't find your profile. Try again."
            return nil
        }

        let goal = Goal(id: Identifier(), kind: goalKind, metric: nil, target: nil, deadline: nil)
        let updatedPerson = Person(
            id: person.id,
            displayName: person.displayName,
            roles: person.roles,
            goals: person.goals + [goal]
        )

        do {
            _ = try await backend.people.upsert(updatedPerson)
        } catch {
            saveErrorMessage = "Couldn't save your goal. Try again."
            return nil
        }

        if let engagementID {
            let summary = Self.intakeSummary(
                goalKind: goalKind,
                experience: experienceLevel,
                injuries: injuriesText,
                preferences: preferencesText
            )
            try? await backend.messages.send(
                Message(id: Identifier(), engagementID: engagementID, authorID: clientID, body: summary, sentAt: clock())
            )
        }

        saveErrorMessage = nil
        return goal
    }

    /// A human-readable summary of the structured intake, sent to the coach
    /// as a message so it's stored against the engagement (see
    /// `submit()`). Free-text fields are omitted entirely when blank rather
    /// than shown empty.
    static func intakeSummary(goalKind: GoalKind, experience: ExperienceLevel, injuries: String, preferences: String) -> String {
        var parts = ["New intake — goal: \(goalKind.displayName), experience: \(experience.displayName)."]
        let trimmedInjuries = injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInjuries.isEmpty {
            parts.append("Injuries/limitations: \(trimmedInjuries).")
        }
        let trimmedPreferences = preferences.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreferences.isEmpty {
            parts.append("Preferences: \(trimmedPreferences).")
        }
        return parts.joined(separator: " ")
    }
}
