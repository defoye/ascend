import Domain
import Foundation
import Testing
@testable import Features

@Suite("ScheduleSummaries")
struct ScheduleSummariesTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1 // Sunday, deterministic regardless of test-runner locale.
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("sessions(on:) keeps only same-calendar-day sessions, ascending")
    func filtersToSingleDay() {
        let engagementID = Identifier<Engagement>()
        let target = Self.date(2024, 3, 12)
        let sessions = [
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 12, hour: 18), status: .scheduled), clientName: "Evening"),
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 12, hour: 9), status: .scheduled), clientName: "Morning"),
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 13), status: .scheduled), clientName: "NextDay")
        ]

        let result = ScheduleSummaries.sessions(sessions, on: target, calendar: Self.calendar)

        #expect(result.map(\.clientName) == ["Morning", "Evening"])
    }

    @Test("sessions(inWeekContaining:) keeps only sessions within that calendar week")
    func filtersToWeek() {
        let engagementID = Identifier<Engagement>()
        let midWeek = Self.date(2024, 3, 13) // a Wednesday
        let sessions = [
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 11), status: .scheduled), clientName: "SameWeek"),
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 25), status: .scheduled), clientName: "NextWeek")
        ]

        let result = ScheduleSummaries.sessions(sessions, inWeekContaining: midWeek, calendar: Self.calendar)

        #expect(result.map(\.clientName) == ["SameWeek"])
    }

    @Test("groupedByDay groups and sorts by calendar day, each day ascending by time")
    func groupsByDay() {
        let engagementID = Identifier<Engagement>()
        let sessions = [
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 13, hour: 15), status: .scheduled), clientName: "B"),
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 12, hour: 9), status: .scheduled), clientName: "A1"),
            ScheduledSession(session: Session(id: Identifier(), engagementID: engagementID, scheduledAt: Self.date(2024, 3, 12, hour: 18), status: .scheduled), clientName: "A2")
        ]

        let groups = ScheduleSummaries.groupedByDay(sessions, calendar: Self.calendar)

        #expect(groups.count == 2)
        #expect(groups[0].sessions.map(\.clientName) == ["A1", "A2"])
        #expect(groups[1].sessions.map(\.clientName) == ["B"])
    }

    @Test("nextDay/previousDay and nextWeek/previousWeek move by the expected interval")
    func navigationHelpersMoveByExpectedInterval() {
        let start = Self.date(2024, 3, 12)
        #expect(ScheduleSummaries.nextDay(from: start, calendar: Self.calendar) == Self.date(2024, 3, 13))
        #expect(ScheduleSummaries.previousDay(from: start, calendar: Self.calendar) == Self.date(2024, 3, 11))
        #expect(ScheduleSummaries.nextWeek(from: start, calendar: Self.calendar) == Self.date(2024, 3, 19))
        #expect(ScheduleSummaries.previousWeek(from: start, calendar: Self.calendar) == Self.date(2024, 3, 5))
    }

    @Test("windows(on:) returns only the windows matching that date's weekday")
    func windowsFilterByWeekday() {
        let professionalID = Identifier<Person>()
        let tuesday = Self.date(2024, 3, 12) // a Tuesday: weekday 3
        let windows = [
            AvailabilityWindow(id: Identifier(), professionalID: professionalID, weekday: 3, startMinute: 540, endMinute: 1_020),
            AvailabilityWindow(id: Identifier(), professionalID: professionalID, weekday: 4, startMinute: 540, endMinute: 1_020)
        ]

        let result = ScheduleSummaries.windows(windows, on: tuesday, calendar: Self.calendar)

        #expect(result.count == 1)
        #expect(result.first?.weekday == 3)
    }
}
