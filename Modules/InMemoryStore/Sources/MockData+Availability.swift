import Domain
import Foundation

extension MockData {
    /// A few weekly recurring availability windows for the seeded
    /// professional (Jordan Ellis) — enough to exercise
    /// `AvailabilityRepository` and give the schedule's availability
    /// context non-empty previews. Weekdays match `Calendar`'s `weekday`
    /// component (1 = Sunday ... 7 = Saturday).
    static func seedAvailabilityWindows() -> [AvailabilityWindow] {
        [
            // Monday 9am-5pm
            AvailabilityWindow(
                id: Identifier(uuid(19, 0)),
                professionalID: professionalPersonID,
                weekday: 2,
                startMinute: 9 * 60,
                endMinute: 17 * 60
            ),
            // Tuesday 9am-5pm
            AvailabilityWindow(
                id: Identifier(uuid(19, 1)),
                professionalID: professionalPersonID,
                weekday: 3,
                startMinute: 9 * 60,
                endMinute: 17 * 60
            ),
            // Wednesday morning only
            AvailabilityWindow(
                id: Identifier(uuid(19, 2)),
                professionalID: professionalPersonID,
                weekday: 4,
                startMinute: 9 * 60,
                endMinute: 12 * 60
            ),
            // Thursday afternoon
            AvailabilityWindow(
                id: Identifier(uuid(19, 3)),
                professionalID: professionalPersonID,
                weekday: 5,
                startMinute: 13 * 60,
                endMinute: 18 * 60
            ),
            // Friday 9am-3pm
            AvailabilityWindow(
                id: Identifier(uuid(19, 4)),
                professionalID: professionalPersonID,
                weekday: 6,
                startMinute: 9 * 60,
                endMinute: 15 * 60
            )
        ]
    }
}
