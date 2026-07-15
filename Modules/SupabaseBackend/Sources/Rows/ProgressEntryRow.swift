import Domain
import Foundation

struct ProgressEntryRow: SupabaseRow {
    let id: Identifier<ProgressEntry>
    let engagementID: Identifier<Engagement>
    let metric: MetricKind
    let value: Double
    let unit: MetricUnit
    let recordedAt: Date
    let source: ProgressSource

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case engagementID = "engagement_id"
        case metric
        case value
        case unit
        case recordedAt = "recorded_at"
        case source
    }

    init(domain: ProgressEntry) {
        id = domain.id
        engagementID = domain.engagementID
        metric = domain.metric
        value = domain.value.value
        unit = domain.value.unit
        recordedAt = domain.recordedAt
        source = domain.source
    }

    var toDomain: ProgressEntry {
        ProgressEntry(
            id: id,
            engagementID: engagementID,
            metric: metric,
            value: MetricValue(value: value, unit: unit),
            recordedAt: recordedAt,
            source: source
        )
    }
}
