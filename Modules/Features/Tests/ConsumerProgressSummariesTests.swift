import Domain
import Foundation
import Testing
@testable import Features

@Suite("ConsumerProgressSummaries")
struct ConsumerProgressSummariesTests {
    private static let calendar = Calendar(identifier: .gregorian)
    private static let dayZero = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(daysAgo: Int, metric: MetricKind = .bodyweight, value: Double = 200, unit: MetricUnit = .lb) -> ProgressEntry {
        ProgressEntry(
            id: Identifier(),
            engagementID: Identifier(),
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: Self.dayZero.addingTimeInterval(Double(-daysAgo) * 86_400),
            source: .clientSelfReported
        )
    }

    @Test("currentStreakDays counts consecutive logged calendar days ending at now")
    func currentStreakCountsConsecutiveDays() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 1), entry(daysAgo: 2), entry(daysAgo: 5)]
        let streak = ConsumerProgressSummaries.currentStreakDays(entries: entries, now: Self.dayZero, calendar: Self.calendar)
        #expect(streak == 3)
    }

    @Test("currentStreakDays is zero when today has no logged entry")
    func currentStreakZeroWithoutTodayEntry() {
        let entries = [entry(daysAgo: 1), entry(daysAgo: 2)]
        let streak = ConsumerProgressSummaries.currentStreakDays(entries: entries, now: Self.dayZero, calendar: Self.calendar)
        #expect(streak == 0)
    }

    @Test("longestStreakDays finds the longest run anywhere in history, not just ending at now")
    func longestStreakFindsBestRunAnywhere() {
        // A 4-day run in the past (days 10-13 ago), then a gap, then a lone entry.
        let entries = [entry(daysAgo: 10), entry(daysAgo: 11), entry(daysAgo: 12), entry(daysAgo: 13), entry(daysAgo: 0)]
        let longest = ConsumerProgressSummaries.longestStreakDays(entries: entries, calendar: Self.calendar)
        #expect(longest == 4)
    }

    @Test("longestStreakDays is 1 for a single entry, 0 for no entries")
    func longestStreakEdgeCases() {
        #expect(ConsumerProgressSummaries.longestStreakDays(entries: [entry(daysAgo: 0)], calendar: Self.calendar) == 1)
        #expect(ConsumerProgressSummaries.longestStreakDays(entries: [], calendar: Self.calendar) == 0)
    }

    @Test("milestones is empty for no entries, and includes a directional delta once a metric has 2+ points")
    func milestonesIncludesMetricDeltaOnceThereAreTwoPoints() {
        #expect(ConsumerProgressSummaries.milestones(from: [], now: Self.dayZero, calendar: Self.calendar).isEmpty)

        let entries = [
            entry(daysAgo: 30, metric: .bodyweight, value: 210),
            entry(daysAgo: 0, metric: .bodyweight, value: 196)
        ]
        let milestones = ConsumerProgressSummaries.milestones(from: entries, now: Self.dayZero, calendar: Self.calendar)

        #expect(milestones.contains { $0.id == "total" && $0.value == "2" })
        #expect(milestones.contains { $0.id == "metric-bodyweight" })
        let metricMilestone = milestones.first { $0.id == "metric-bodyweight" }
        #expect(metricMilestone?.value.contains("14") == true) // |196 - 210| = 14
    }

    @Test("milestones omits a metric delta when only one point is logged for it")
    func milestonesOmitsSinglePointMetric() {
        let entries = [entry(daysAgo: 0, metric: .squat1RM, value: 200)]
        let milestones = ConsumerProgressSummaries.milestones(from: entries, now: Self.dayZero, calendar: Self.calendar)
        #expect(!milestones.contains { $0.id == "metric-squat1RM" })
        #expect(milestones.contains { $0.id == "total" })
    }
}
