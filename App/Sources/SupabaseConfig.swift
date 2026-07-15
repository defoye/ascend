import Foundation

/// Reads `SUPABASE_URL`/`SUPABASE_ANON_KEY` out of the app's Info.plist,
/// where they land via `$(SUPABASE_URL)`/`$(SUPABASE_ANON_KEY)` build-setting
/// substitution (see `Project.swift`'s `appInfoPlist`) backed by
/// `Config/Secrets.xcconfig` in Release (gitignored, owner-provided — see
/// docs/BACKEND.md). This is the App target's job, not `SupabaseBackend`'s:
/// the adapter module stays Info.plist/Bundle-agnostic and just takes a URL +
/// key, exactly like every other composition-root-only concern (see
/// docs/ARCHITECTURE.md).
enum SupabaseConfig {
    struct Credentials {
        let url: URL
        let anonKey: String
    }

    enum ConfigError: Error, CustomStringConvertible {
        case missingURL
        case invalidURL(String)
        case missingAnonKey

        var description: String {
            switch self {
            case .missingURL:
                "SUPABASE_URL is missing from Info.plist — is Config/Secrets.xcconfig present? See docs/BACKEND.md."
            case .invalidURL(let raw):
                "SUPABASE_URL (\"\(raw)\") did not parse as a URL."
            case .missingAnonKey:
                "SUPABASE_ANON_KEY is missing from Info.plist — is Config/Secrets.xcconfig present? See docs/BACKEND.md."
            }
        }
    }

    /// Reads and validates both values from `bundle`'s Info.plist.
    ///
    /// - Important: `Config/Secrets.xcconfig` escapes `SUPABASE_URL`'s `//` as
    ///   `https:/$()/host` to survive xcconfig's "`//` starts a comment" rule
    ///   (the empty `$()` substitution is resolved by the build system while
    ///   parsing the xcconfig itself, before the value ever becomes a build
    ///   setting) — by the time it reaches Info.plist substitution and lands
    ///   here, the value is already the plain `https://host` form. No
    ///   unescaping is needed at this layer; verified for real by inspecting
    ///   `xcodebuild -showBuildSettings -configuration Release`'s resolved
    ///   `SUPABASE_URL` (there is no App unit-test target to assert this in —
    ///   see docs/BUILD_STATUS.md for the exact command run to confirm it).
    static func read(bundle: Bundle = .main) throws -> Credentials {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !rawURL.isEmpty
        else {
            throw ConfigError.missingURL
        }
        guard let url = URL(string: rawURL) else {
            throw ConfigError.invalidURL(rawURL)
        }
        guard
            let anonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty
        else {
            throw ConfigError.missingAnonKey
        }
        return Credentials(url: url, anonKey: anonKey)
    }
}
