import DataInterfaces
import Domain

extension InMemoryBackend: PaymentRepository {
    public func get(_ id: Identifier<Payment>) async throws -> Payment? {
        paymentsByID[id]
    }

    public func upsert(_ payment: Payment) async throws -> Payment {
        paymentsByID[payment.id] = payment
        return payment
    }

    public func delete(_ id: Identifier<Payment>) async throws {
        guard paymentsByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }

    public func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment] {
        paymentsByID.values.filter { $0.engagementID == engagementID }
    }
}
