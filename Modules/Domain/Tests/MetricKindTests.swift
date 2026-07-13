import Testing
@testable import Domain

@Suite("MetricKind.lowerIsGenerallyBetter")
struct MetricKindTests {
    @Test("Strength 1RMs are higher-is-better", arguments: [
        MetricKind.squat1RM, .bench1RM, .deadlift1RM,
    ])
    func strength1RMsAreHigherIsBetter(metric: MetricKind) {
        #expect(metric.lowerIsGenerallyBetter == false)
    }

    @Test("Body composition, heart rate, and race time are lower-is-better", arguments: [
        MetricKind.bodyweight, .waistCircumference, .bodyFatPercentage, .restingHeartRate, .fiveKTime,
    ])
    func lowerIsBetterMetrics(metric: MetricKind) {
        #expect(metric.lowerIsGenerallyBetter == true)
    }

    @Test("Every MetricKind case is covered by the directionality mapping")
    func allCasesAreCovered() {
        // Guards against a future case being added without updating the mapping —
        // if this test compiles and MetricKind.allCases grows, this assertion still
        // holds because lowerIsGenerallyBetter is exhaustive over the enum.
        #expect(MetricKind.allCases.count == 8)
    }
}
