import Domain
import Foundation

/// Row for the `device_tokens` table. Encodable-only (never decoded) — device
/// tokens skip the offline-write queue (see
/// `SupabaseBackend+DeviceTokenRepository.swift`), so this doesn't need
/// `SupabaseRow`/a `rowID` or a `Decodable` conformance. No `id` field: the
/// table column has a database default (`gen_random_uuid()`).
struct DeviceTokenRow: Encodable, Sendable {
    let personID: Identifier<Person>
    let token: String
    let platform: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case personID = "person_id"
        case token
        case platform
        case updatedAt = "updated_at"
    }
}
