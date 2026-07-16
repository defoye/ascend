import DataInterfaces
import Domain
import Foundation
import Supabase

/// `device_tokens` writes are best-effort, direct Postgres calls — not routed
/// through `OfflineWriteQueue` like `SupabaseTable`-backed repositories.
/// Losing a registration while offline just means this device doesn't
/// receive a push until it registers again on next launch; there's no
/// user-visible data loss worth the queue's replay complexity for it.
extension SupabaseBackend: DeviceTokenRepository {
    public func register(token: String, platform: String) async throws {
        let session = try await client.auth.session
        let personID = Identifier<Person>(session.user.id)
        let row = DeviceTokenRow(personID: personID, token: token, platform: platform, updatedAt: Date())
        try await client.from("device_tokens").upsert(row, onConflict: "token").execute()
    }

    public func unregister(token: String) async throws {
        try await client.from("device_tokens").delete().eq("token", value: token).execute()
    }
}
