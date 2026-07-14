import DataInterfaces
import Domain
import Foundation

// MARK: - Availability fixtures
//
// Split into its own file (rather than kept in `PreviewBackend.swift`) purely
// to stay under SwiftLint's `file_length` — SwiftLint measures each file
// independently.
extension PreviewBackend {
    static func makeAvailabilityWindows(professionalID: Identifier<Person>) -> [AvailabilityWindow] {
        [
            AvailabilityWindow(id: Identifier(), professionalID: professionalID, weekday: 2, startMinute: 9 * 60, endMinute: 17 * 60),
            AvailabilityWindow(id: Identifier(), professionalID: professionalID, weekday: 4, startMinute: 9 * 60, endMinute: 12 * 60)
        ]
    }
}

struct PreviewAvailabilityRepository: AvailabilityRepository {
    let windowsList: [AvailabilityWindow]
    func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow] {
        windowsList.filter { $0.professionalID == professionalID }
    }
    func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow { window }
    func delete(_ id: Identifier<AvailabilityWindow>) async throws {}
}
