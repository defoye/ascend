import Domain
import Foundation
import Testing
@testable import SupabaseBackend

/// Proves the Row DTO <-> Domain mapping this whole module leans on:
/// `Identifier<Entity>` round-trips as a bare UUID string through
/// `SupabaseBackend.jsonEncoder`/`jsonDecoder` (the same encoder/decoder
/// pair PostgREST itself uses — see `SupabaseBackend.swift`), and each Row's
/// explicit `CodingKeys` actually produce the snake_case column names
/// Postgres expects (PostgREST's default decoder does NOT auto-convert
/// casing, so a missing `CodingKeys` case would silently decode with `nil`/
/// default values against real data instead of failing loudly here).
@Suite("Row Coding")
struct RowCodingTests {
    @Test("PersonRow round-trips through the module's encoder/decoder")
    func personRowRoundTrips() throws {
        let personID = Identifier<Person>()
        let row = PersonRow(id: personID, displayName: "Jordan Ellis", roles: [.professional])

        let data = try SupabaseBackend.jsonEncoder.encode(row)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"display_name\""))
        #expect(!json.contains("\"displayName\""))

        let decoded = try SupabaseBackend.jsonDecoder.decode(PersonRow.self, from: data)
        #expect(decoded.id == personID)
        #expect(decoded.displayName == "Jordan Ellis")
        #expect(decoded.roles == [.professional])
    }

    @Test("PersonRow.rowID is the bare Identifier string used as the offline-queue key")
    func personRowIDMatchesIdentifier() {
        let personID = Identifier<Person>()
        let row = PersonRow(id: personID, displayName: "x", roles: [])
        #expect(row.rowID == personID.rawValue)
    }

    @Test("EngagementRow round-trips consent flags and snake_case keys")
    func engagementRowRoundTrips() throws {
        let engagement = Engagement(
            id: Identifier(),
            clientID: Identifier(),
            professionalID: Identifier(),
            status: .active,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: nil
        )
        let row = EngagementRow(domain: engagement, consentGranted: true, photoConsentGranted: false)

        let data = try SupabaseBackend.jsonEncoder.encode(row)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"consent_granted\""))
        #expect(json.contains("\"photo_consent_granted\""))
        #expect(json.contains("\"client_id\""))

        let decoded = try SupabaseBackend.jsonDecoder.decode(EngagementRow.self, from: data)
        #expect(decoded.toDomain == engagement)
        #expect(decoded.consentGranted == true)
        #expect(decoded.photoConsentGranted == false)
    }

    @Test("EngagementInviteRow round-trips snake_case keys and nil claim fields")
    func engagementInviteRowRoundTrips() throws {
        let invite = EngagementInvite(
            id: Identifier(),
            code: "ABCD2345",
            professionalID: Identifier(),
            suggestedClientName: "Jordan",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            claimedByPersonID: nil,
            claimedAt: nil,
            engagementID: nil
        )
        let row = EngagementInviteRow(domain: invite)

        let data = try SupabaseBackend.jsonEncoder.encode(row)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"professional_id\""))
        #expect(json.contains("\"suggested_client_name\""))

        let decoded = try SupabaseBackend.jsonDecoder.decode(EngagementInviteRow.self, from: data)
        #expect(decoded.toDomain == invite)
        #expect(decoded.claimedBy == nil)
        #expect(decoded.claimedAt == nil)
        #expect(decoded.engagementID == nil)
    }

    @Test("EngagementInviteRow round-trips a claimed invite's claim fields")
    func engagementInviteRowRoundTripsClaimed() throws {
        let invite = EngagementInvite(
            id: Identifier(),
            code: "WXYZ6789",
            professionalID: Identifier(),
            suggestedClientName: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            claimedByPersonID: Identifier(),
            claimedAt: Date(timeIntervalSince1970: 1_700_001_000),
            engagementID: Identifier()
        )
        let row = EngagementInviteRow(domain: invite)

        let data = try SupabaseBackend.jsonEncoder.encode(row)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"claimed_by\""))
        #expect(json.contains("\"claimed_at\""))
        #expect(json.contains("\"engagement_id\""))

        let decoded = try SupabaseBackend.jsonDecoder.decode(EngagementInviteRow.self, from: data)
        #expect(decoded.toDomain == invite)
    }

    @Test("ProgressEntryRow flattens MetricValue into value/unit columns")
    func progressEntryRowFlattensMetricValue() throws {
        let entry = ProgressEntry(
            id: Identifier(),
            engagementID: Identifier(),
            metric: .squat1RM,
            value: MetricValue(value: 225, unit: .lb),
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .coachRecorded
        )
        let row = ProgressEntryRow(domain: entry)

        let data = try SupabaseBackend.jsonEncoder.encode(row)
        let decoded = try SupabaseBackend.jsonDecoder.decode(ProgressEntryRow.self, from: data)

        #expect(decoded.toDomain == entry)
    }
}
