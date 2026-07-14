import Domain

/// CRUD access to a coach's recurring weekly `AvailabilityWindow`s.
public protocol AvailabilityRepository: Sendable {
    /// One-shot fetch of every availability window for a professional.
    func windows(forProfessional professionalID: Identifier<Person>) async throws -> [AvailabilityWindow]
    func upsert(_ window: AvailabilityWindow) async throws -> AvailabilityWindow
    func delete(_ id: Identifier<AvailabilityWindow>) async throws
}
