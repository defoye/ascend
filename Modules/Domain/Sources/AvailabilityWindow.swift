import Foundation

/// A coach's recurring weekly availability window (e.g. "Mondays 9am-5pm"),
/// used to give a schedule view context for when the professional is
/// generally open for sessions. Purely descriptive — it does not block
/// booking a session outside a window.
public struct AvailabilityWindow: Identifiable, Codable, Sendable, Hashable {
    public let id: Identifier<AvailabilityWindow>
    public let professionalID: Identifier<Person>
    /// 1 = Sunday ... 7 = Saturday, matching `Calendar`'s `weekday` component.
    public let weekday: Int
    /// Minutes after midnight the window opens (e.g. `9 * 60` for 9:00 AM).
    public let startMinute: Int
    /// Minutes after midnight the window closes.
    public let endMinute: Int

    public init(
        id: Identifier<AvailabilityWindow>,
        professionalID: Identifier<Person>,
        weekday: Int,
        startMinute: Int,
        endMinute: Int
    ) {
        self.id = id
        self.professionalID = professionalID
        self.weekday = weekday
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Whether this window's fields describe a sane, non-empty span within a
    /// single day. Purely a UI-validation convenience — not enforced by the
    /// initializer, since `Domain` types stay plain value holders.
    public var isValid: Bool {
        (1...7).contains(weekday) && startMinute >= 0 && endMinute <= 24 * 60 && startMinute < endMinute
    }
}
