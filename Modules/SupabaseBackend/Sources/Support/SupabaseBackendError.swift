import Foundation

/// Errors specific to the Supabase adapter's own bookkeeping (not PostgREST/Auth/
/// Storage errors, which propagate from the SDK as-is).
public enum SupabaseBackendError: Error, Sendable, Equatable {
    /// A `get`/`fetchOne`-style lookup found no row for the requested id.
    case notFound
    /// `SUPABASE_URL` (from Info.plist / `Config/Secrets.xcconfig`) was missing or
    /// not a valid URL at composition-root construction time.
    case invalidConfiguration(String)
}
