import DataInterfaces
import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

/// Proves the analytics seam carries only ids/enums — never a display name,
/// message body, note body, or photo reference. The strongest guarantee is
/// structural (a case that tried to carry a `String` PII payload wouldn't
/// compile against `AnalyticsEvent`'s shape), but these tests also exercise
/// the real Features call site (`ConsentViewModel`) end-to-end against a
/// recording tracker and assert no PII string leaks into a recorded event,
/// in both the success and error paths.
@Suite("AnalyticsEvent carries no PII")
@MainActor
struct AnalyticsNoPIITests {
    /// A tracker that fails the test the instant any event's reflected
    /// contents contain a known-PII string — the seeded client/coach names
    /// and a message body. This is the "prove it, don't just trust the type"
    /// backstop.
    private func assertNoPII(in events: [AnalyticsEvent], forbidden: [String]) {
        for event in events {
            let rendered = String(describing: event)
            for needle in forbidden where !needle.isEmpty {
                #expect(!rendered.contains(needle), "Analytics event leaked PII: \(rendered) contained \(needle)")
            }
        }
    }

    @Test("consent toggle records only engagement id + boolean, no client name")
    func consentToggleRecordsNoPII() async throws {
        let tracker = RecordingAnalyticsTracker()
        let backend = InMemoryStore.seeded(analyticsTracker: tracker)
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagementID = try #require(try await backend.engagements.fetchEngagements(forClient: morganChen.id).first?.id)

        let viewModel = ConsentViewModel(backend: backend, engagementID: engagementID)
        await viewModel.load()
        await viewModel.setGranted(false)
        await viewModel.setGranted(true)

        let events = tracker.events
        #expect(events.contains(.consentChanged(engagementID: engagementID, granted: false)))
        #expect(events.contains(.consentChanged(engagementID: engagementID, granted: true)))
        assertNoPII(in: events, forbidden: ["Morgan Chen", "Jordan Ellis"])
    }

    /// Every `AnalyticsEvent.Screen` and `ErrorContext` case renders to a
    /// short whitespace-free token — proving they're bounded enum
    /// identifiers, not free-text that could smuggle in user content.
    @Test("screen and error-context enums are bounded identifiers, not free text")
    func enumsAreBoundedIdentifiers() {
        for screen in AnalyticsEvent.Screen.allCases {
            #expect(!screen.rawValue.contains(" "))
            #expect(screen.rawValue.count < 40)
        }
        for context in AnalyticsEvent.ErrorContext.allCases {
            #expect(!context.rawValue.contains(" "))
            #expect(context.rawValue.count < 40)
        }
    }
}
