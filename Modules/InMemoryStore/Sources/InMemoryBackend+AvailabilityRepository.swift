import DataInterfaces
import Domain

extension InMemoryBackend: AvailabilityRepository {
    public func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow] {
        availabilityWindowsByID.values
            .filter { $0.professionalID == professionalID }
            .sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
    }

    public func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow {
        availabilityWindowsByID[window.id] = window
        return window
    }

    public func delete(_ id: Identifier<AvailabilityWindow>) async throws {
        guard availabilityWindowsByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }
}
