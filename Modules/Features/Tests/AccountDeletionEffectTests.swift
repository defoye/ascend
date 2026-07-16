import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

/// Proves `AccountDeletionEffect.deleteAccount` genuinely anonymizes a
/// person, ends their engagements, and removes only their own
/// private/authored data through the real repository protocols against
/// `InMemoryStore.seeded()` — never the other party's sessions, progress,
/// photos, or payments (see the type's doc comment for why: `people` FK
/// cascades would otherwise wipe the other party's shared history).
@Suite("AccountDeletionEffect against seeded data")
@MainActor
struct AccountDeletionEffectTests {
    /// Deleting a client (Morgan Chen, `clientPersonID(1)` / `engagementID(1)`
    /// — see `MockData+Engagements.swift`) ends her engagement and anonymizes
    /// her `Person` record, but leaves the engagement's sessions, progress
    /// entries, photos, and payments — jointly owned with the coach —
    /// completely untouched, and never touches the coach's notes on that
    /// engagement.
    @Test("deleting a client ends only their engagement and anonymizes their Person; the coach's data on that engagement is untouched")
    func deletingClientEndsEngagementAndPreservesCoachData() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagementBefore = try #require(try await backend.engagements.fetchEngagements(forClient: morganChen.id).first)
        #expect(engagementBefore.status == .active)
        let engagementID = engagementBefore.id

        let sessionsBefore = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        let progressBefore = try await backend.progress.fetchEntries(forEngagement: engagementID)
        let photosBefore = try await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)
        let paymentsBefore = try await backend.payments.payments(forEngagement: engagementID)
        let notesBefore = try await backend.notes.notes(forEngagement: engagementID)
        #expect(!sessionsBefore.isEmpty)
        #expect(!progressBefore.isEmpty)
        #expect(!photosBefore.isEmpty)
        #expect(!paymentsBefore.isEmpty)
        #expect(!notesBefore.isEmpty)

        let jordanEllis = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let samPatelEngagement = try #require(
            try await backend.engagements.fetchEngagements(forProfessional: jordanEllis.id).first { $0.id != engagementID }
        )

        let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
        let summary = await AccountDeletionEffect.deleteAccount(personID: morganChen.id, backend: backend, clock: { fixedNow })

        #expect(summary.personAnonymized)
        #expect(summary.engagementsEnded == 1)
        #expect(summary.notesDeleted == 0) // Morgan is the client, not the professional — the coach's notes survive.

        // The engagement is ended, not deleted, and stamped with the injected clock.
        let engagementAfter = try #require(try await backend.engagements.get(engagementID))
        #expect(engagementAfter.status == .ended)
        #expect(engagementAfter.endedAt == fixedNow)

        // Everything scoped to the engagement is untouched — it belongs to the relationship, not just Morgan.
        let sessionsAfter = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        #expect(sessionsAfter.count == sessionsBefore.count)
        let progressAfter = try await backend.progress.fetchEntries(forEngagement: engagementID)
        #expect(progressAfter.count == progressBefore.count)
        let photosAfter = try await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)
        #expect(photosAfter.count == photosBefore.count)
        let paymentsAfter = try await backend.payments.payments(forEngagement: engagementID)
        #expect(paymentsAfter.count == paymentsBefore.count)
        let notesAfter = try await backend.notes.notes(forEngagement: engagementID)
        #expect(notesAfter.count == notesBefore.count)

        // Morgan's Person record is anonymized, not removed.
        let personAfter = try #require(try await backend.people.get(morganChen.id))
        #expect(personAfter.displayName == "Deleted user")
        #expect(personAfter.roles.isEmpty)
        #expect(personAfter.goals.isEmpty)

        // Jordan Ellis and every other client's engagement are untouched.
        let jordanAfter = try #require(try await backend.people.get(jordanEllis.id))
        #expect(jordanAfter.displayName == "Jordan Ellis")
        let samEngagementAfter = try #require(try await backend.engagements.get(samPatelEngagement.id))
        #expect(samEngagementAfter.status == samPatelEngagement.status)
    }

    /// Deleting the professional (Jordan Ellis) ends every non-terminal
    /// engagement they're a party to, deletes their coach notes (private,
    /// coach-authored data — see `MockData+Notes.swift`), programs,
    /// availability windows, and professional profile, and anonymizes their
    /// `Person` record — but never touches an engagement that's already
    /// `.completed`/`.ended`.
    @Test("deleting the professional ends non-terminal engagements, deletes their notes/programs/availability/profile, and anonymizes their Person")
    func deletingProfessionalRemovesTheirBusinessDataAndPreservesTerminalEngagements() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let jordanEllis = try #require(people.first { $0.displayName == "Jordan Ellis" })

        let engagementsBefore = try await backend.engagements.fetchEngagements(forProfessional: jordanEllis.id)
        let nonTerminalBefore = engagementsBefore.filter { $0.status != .ended && $0.status != .completed }
        let terminalBefore = engagementsBefore.filter { $0.status == .ended || $0.status == .completed }
        #expect(!nonTerminalBefore.isEmpty)
        #expect(!terminalBefore.isEmpty)

        let programsBefore = try await backend.programs.list(forAuthor: jordanEllis.id)
        let windowsBefore = try await backend.availability.windows(forProfessional: jordanEllis.id)
        #expect(!programsBefore.isEmpty)
        let profileBefore = try await backend.professionals.profile(forProfessional: jordanEllis.id)
        #expect(profileBefore != nil)

        let summary = await AccountDeletionEffect.deleteAccount(personID: jordanEllis.id, backend: backend)

        #expect(summary.personAnonymized)
        #expect(summary.professionalProfileDeleted)
        #expect(summary.programsDeleted == programsBefore.count)
        #expect(summary.availabilityWindowsDeleted == windowsBefore.count)
        #expect(summary.engagementsEnded == nonTerminalBefore.count)
        #expect(summary.notesDeleted == 2) // seeded notes on engagement 1 and 2, both authored by Jordan.

        for engagement in nonTerminalBefore {
            let after = try #require(try await backend.engagements.get(engagement.id))
            #expect(after.status == .ended)
        }
        for engagement in terminalBefore {
            let after = try #require(try await backend.engagements.get(engagement.id))
            #expect(after.status == engagement.status)
            #expect(after.endedAt == engagement.endedAt)
        }

        let personAfter = try #require(try await backend.people.get(jordanEllis.id))
        #expect(personAfter.displayName == "Deleted user")
        #expect(personAfter.roles.isEmpty)
        let profileAfter = try await backend.professionals.profile(forProfessional: jordanEllis.id)
        #expect(profileAfter == nil)
        let programsAfter = try await backend.programs.list(forAuthor: jordanEllis.id)
        #expect(programsAfter.isEmpty)
    }

    /// Deleting a person with no engagements and no professional profile
    /// (a brand-new, unconnected `Person`) is a no-op sweep that still
    /// successfully anonymizes the `Person` record — never a crash or a
    /// stuck partial state.
    @Test("deleting a person with no data at all still anonymizes the Person record cleanly")
    func deletingPersonWithNoDataStillSucceeds() async throws {
        let backend = InMemoryStore.seeded()
        let newPerson = Person(id: Identifier(), displayName: "Nobody Yet", roles: [.consumer], goals: [])
        _ = try await backend.people.upsert(newPerson)

        let summary = await AccountDeletionEffect.deleteAccount(personID: newPerson.id, backend: backend)

        #expect(summary.personAnonymized)
        #expect(summary.engagementsEnded == 0)
        #expect(summary.notesDeleted == 0)
        #expect(summary.professionalProfileDeleted == false)

        let personAfter = try #require(try await backend.people.get(newPerson.id))
        #expect(personAfter.displayName == "Deleted user")
        #expect(personAfter.roles.isEmpty)
    }

    /// Deleting an account that doesn't exist at all reports
    /// `personAnonymized == false` rather than crashing or lying about
    /// success.
    @Test("deleting a nonexistent account reports failure, not a crash")
    func deletingNonexistentAccountReportsFailure() async {
        let backend = InMemoryStore.seeded()
        let summary = await AccountDeletionEffect.deleteAccount(personID: Identifier(), backend: backend)
        #expect(!summary.personAnonymized)
    }
}
