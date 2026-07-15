import Foundation

/// A Postgres row DTO: `Codable` with explicit `CodingKeys` mapping
/// camelCase Swift properties to this table's snake_case columns (PostgREST's
/// default decoder does not auto-convert casing — see
/// `SupabaseBackend.jsonDecoder`), plus a stable string row id for the
/// offline-write-queue and read-overlay machinery in `SupabaseTable`.
public protocol SupabaseRow: Codable, Sendable {
    var rowID: String { get }
}
