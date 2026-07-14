import Foundation

/// Small date/time formatting helpers shared by the schedule and
/// availability-editor views: converting an `AvailabilityWindow`'s
/// minutes-from-midnight fields to/from a display `Date` and weekday name.
enum ScheduleFormatting {
    static func weekdaySymbol(_ weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "Unknown" }
        return symbols[index]
    }

    static func timeString(fromMinutes minutes: Int, calendar: Calendar = .current) -> String {
        date(fromMinutes: minutes, calendar: calendar).formatted(date: .omitted, time: .shortened)
    }

    /// A `Date` (on today's calendar day) whose hour/minute encode `minutes`
    /// past midnight — a convenient handle for `DatePicker`'s `.hourAndMinute`.
    static func date(fromMinutes minutes: Int, calendar: Calendar = .current) -> Date {
        let hour = minutes / 60
        let minute = minutes % 60
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    /// The inverse of `date(fromMinutes:)`: minutes past midnight for `date`'s
    /// hour/minute components.
    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
