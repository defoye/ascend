import Domain

/// CRUD access to `Payment` records, scoped to an engagement.
public protocol PaymentRepository: Sendable {
    func get(_ id: Identifier<Payment>) async throws -> Payment?
    func upsert(_ payment: Payment) async throws -> Payment
    func delete(_ id: Identifier<Payment>) async throws
    func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment]
}
