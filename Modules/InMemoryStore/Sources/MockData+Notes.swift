import Domain
import Foundation

extension MockData {
    /// A couple of seeded `CoachNote`s, on engagements 1 (Morgan Chen) and 2
    /// (Sam Patel) — enough to exercise `NotesRepository` and give
    /// `ClientDetailView` non-empty previews without seeding every engagement.
    static func coachNotes() -> [CoachNote] {
        [
            CoachNote(
                id: Identifier(uuid(18, 0)),
                engagementID: engagementID(1),
                authorID: professionalPersonID,
                body: "Responds well to weekly check-ins. Keep the diet changes simple — she's overwhelmed by too many rules at once.",
                createdAt: date(-90),
                updatedAt: date(-90)
            ),
            CoachNote(
                id: Identifier(uuid(18, 1)),
                engagementID: engagementID(2),
                authorID: professionalPersonID,
                body: "Squat depth has been inconsistent under heavier loads — cue hip mobility drills before adding weight next block.",
                createdAt: date(-60),
                updatedAt: date(-55)
            )
        ]
    }
}
