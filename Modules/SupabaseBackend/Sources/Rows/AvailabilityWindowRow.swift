import Domain
import Foundation

struct AvailabilityWindowRow: SupabaseRow {
    let id: Identifier<AvailabilityWindow>
    let professionalID: Identifier<Person>
    let weekday: Int
    let startMinute: Int
    let endMinute: Int

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case professionalID = "professional_id"
        case weekday
        case startMinute = "start_minute"
        case endMinute = "end_minute"
    }

    init(domain: AvailabilityWindow) {
        id = domain.id
        professionalID = domain.professionalID
        weekday = domain.weekday
        startMinute = domain.startMinute
        endMinute = domain.endMinute
    }

    var toDomain: AvailabilityWindow {
        AvailabilityWindow(id: id, professionalID: professionalID, weekday: weekday, startMinute: startMinute, endMinute: endMinute)
    }
}
