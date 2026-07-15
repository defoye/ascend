import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: AvailabilityRepository {
    public func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow] {
        let rows = try await availabilityTable.fetchAll { $0.eq("professional_id", value: professionalID.rawValue) }
        return rows.map(\.toDomain).sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
    }

    public func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow {
        try await availabilityTable.upsert(AvailabilityWindowRow(domain: window))
        return window
    }

    public func delete(_ id: Identifier<AvailabilityWindow>) async throws {
        try await availabilityTable.delete(id: id.rawValue)
    }

    var availabilityTable: SupabaseTable<AvailabilityWindowRow> {
        SupabaseTable(client: client, queue: queue, table: "availability_windows")
    }
}
