import DataInterfaces
import Domain
import Foundation

/// Deterministic seed data for `InMemoryBackend.seeded()`.
///
/// Everything here is fixed — fixed UUIDs (via `uuid(category:index:)`), fixed
/// dates (relative to `referenceDate`), no randomness — so the fixture is
/// reproducible across runs, previews, and tests (see docs/TESTING.md).
///
/// The data models one professional (the app's owner, a strength/weight-loss
/// coach) and eight clients spread across every `EngagementStatus`, chosen so
/// that at least three of those engagements independently satisfy every pillar
/// of `VerifiedOutcome.derive` (see `MockData+Engagements.swift`).
public enum MockData {
    /// A fully assembled set of seed data, ready to load into `InMemoryBackend`.
    public struct Snapshot: Sendable {
        public let people: [Person]
        public let professionalProfiles: [ProfessionalProfile]
        public let engagements: [Engagement]
        public let consentByEngagement: [Identifier<Engagement>: Bool]
        public let programs: [Program]
        public let programAssignments: [ProgramAssignment]
        public let sessions: [Session]
        public let progressEntries: [ProgressEntry]
        public let payments: [Payment]
        public let messages: [Message]
        public let demoCredentials: DemoCredentials
    }

    /// The demo sign-in for the seeded professional (the app's owner).
    public struct DemoCredentials: Sendable {
        public let email: String
        public let password: String
        public let user: AuthenticatedUser
    }

    /// Anchor date all fixture dates are relative to. Deliberately not `Date()` —
    /// a fixed instant keeps the fixture reproducible.
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z

    /// `referenceDate` offset by `days` (negative = past, positive = future).
    static func date(_ days: Int) -> Date {
        referenceDate.addingTimeInterval(Double(days) * 86_400)
    }

    /// A deterministic UUID: `category` namespaces the entity kind, `index`
    /// distinguishes entities within it, so every id is unique and stable across
    /// runs without relying on `UUID()` randomness.
    static func uuid(_ category: UInt8, _ index: UInt8) -> UUID {
        UUID(uuid: (category, index, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    /// Builds the full seed data set.
    public static func build() -> Snapshot {
        let people = allPeople()
        let profile = professionalProfile()
        let programData = programsAndExercises()
        let activity = activityData()

        return Snapshot(
            people: people,
            professionalProfiles: [profile],
            engagements: activity.engagements,
            consentByEngagement: activity.consentByEngagement,
            programs: programData.programs,
            programAssignments: programData.assignments,
            sessions: activity.sessions,
            progressEntries: activity.progressEntries,
            payments: activity.payments,
            messages: activity.messages,
            demoCredentials: DemoCredentials(
                email: "jordan@ascend.coach",
                password: "password123",
                user: AuthenticatedUser(personID: professionalPersonID, displayName: "Jordan Ellis", email: "jordan@ascend.coach")
            )
        )
    }
}
