import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: PaymentRepository {
    public func get(_ id: Identifier<Payment>) async throws -> Payment? {
        try await paymentsTable.fetchOne(id: id.rawValue)?.toDomain
    }

    public func upsert(_ payment: Payment) async throws -> Payment {
        try await paymentsTable.upsert(PaymentRow(domain: payment))
        return payment
    }

    public func delete(_ id: Identifier<Payment>) async throws {
        try await paymentsTable.delete(id: id.rawValue)
    }

    public func payments(forEngagement engagementID: Identifier<Engagement>) async throws -> [Payment] {
        let rows = try await paymentsTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        return rows.map(\.toDomain).sorted { $0.createdAt < $1.createdAt }
    }

    var paymentsTable: SupabaseTable<PaymentRow> {
        SupabaseTable(client: client, queue: queue, table: "payments")
    }
}
