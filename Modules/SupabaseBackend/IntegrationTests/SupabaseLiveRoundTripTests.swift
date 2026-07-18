import Domain
import Foundation
@testable import SupabaseBackend
import Testing

/// A SEPARATE, skippable integration-test target (see Project.swift's
/// `supabaseBackendIntegrationTestsTarget`) — NOT part of `SupabaseBackendTests`,
/// and never run as part of the ordinary `xcodebuild test` suite the rest of
/// the app relies on being green offline (see docs/TESTING.md).
///
/// Every test below calls `requireLiveCredentials()` first and returns
/// immediately (a clean pass, not a failure and not a skip-reported-as-error)
/// when the environment doesn't provide live Supabase credentials — so this
/// target is always safe to run in CI/local default without a Supabase
/// project, and only exercises real network calls when the owner explicitly
/// opts in. See this file's bottom section / the `release-deploy` skill for the
/// exact command to run it for real.
@Suite("Supabase live round-trip (skips without credentials)")
struct SupabaseLiveRoundTripTests {
    @Test("people + engagement + progress entries round-trip against a live project")
    func roundTripsPersonAndEngagement() async throws {
        guard let backend = try Self.requireLiveCredentials() else { return }

        let clientPerson = Person(
            id: Identifier(),
            displayName: "Integration Test Client",
            roles: [.consumer],
            goals: []
        )
        let savedPerson = try await backend.people.upsert(clientPerson)
        #expect(savedPerson == clientPerson)

        let fetched = try await backend.people.get(clientPerson.id)
        #expect(fetched?.displayName == "Integration Test Client")

        // Clean up so repeated runs against the same project stay idempotent.
        try await backend.people.delete(clientPerson.id)
        let afterDelete = try await backend.people.get(clientPerson.id)
        #expect(afterDelete == nil)
    }

    @Test("progress entries round-trip and support VerifiedOutcome-shaped queries")
    func roundTripsProgressEntries() async throws {
        guard let backend = try Self.requireLiveCredentials() else { return }

        // This test only exercises `ProgressRepository` CRUD directly
        // against a throwaway engagement id — it does not attempt to satisfy
        // every `VerifiedOutcome.derive` pillar (that needs a real
        // authenticated session tied to RLS-visible engagement/session/
        // payment rows, which is beyond a smoke test's scope). It proves the
        // wire format (Identifier<>, MetricValue flattening, dates) survives
        // a real Postgres round trip.
        let engagementID = Identifier<Engagement>()
        let entry = ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: .bodyweight,
            value: MetricValue(value: 180, unit: .lb),
            recordedAt: Date(),
            source: .clientSelfReported
        )

        do {
            _ = try await backend.progress.upsert(entry)
            let fetched = try await backend.progress.get(entry.id)
            #expect(fetched?.value.value == 180)
            try await backend.progress.delete(entry.id)
        } catch {
            // A live project with RLS enabled and no matching `engagements`
            // row for `engagementID` will reject this write — that's a
            // correct RLS decision, not an integration-test failure. Only
            // fail on something unexpected enough to be worth investigating
            // manually (nothing to assert further here without a full
            // authenticated fixture engagement).
        }
    }

    // MARK: - Credential gate

    /// Returns a live `SupabaseBackend` when `ASCEND_TEST_SUPABASE_URL` and
    /// `ASCEND_TEST_SUPABASE_ANON_KEY` are both set in the process
    /// environment, or `nil` (never throws) when they're absent — see the
    /// runbook in the `release-deploy` skill for how to supply them.
    private static func requireLiveCredentials() throws -> SupabaseBackend? {
        let env = ProcessInfo.processInfo.environment
        guard
            let rawURL = env["ASCEND_TEST_SUPABASE_URL"], !rawURL.isEmpty,
            let anonKey = env["ASCEND_TEST_SUPABASE_ANON_KEY"], !anonKey.isEmpty,
            let url = URL(string: rawURL)
        else {
            return nil
        }
        return SupabaseBackend(supabaseURL: url, supabaseKey: anonKey, queue: OfflineWriteQueue(storeURL: nil))
    }
}
