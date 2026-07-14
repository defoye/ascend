import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

/// Proves `AccountDeletionEffect.deleteAccount` genuinely removes a person's
/// data through the real repository protocols against `InMemoryStore.seeded()`
/// — not just returning a plausible-looking summary — and that it scopes
/// correctly: deleting one client never touches another client's data, and
/// deleting the professional cleans up their programs/availability/profile.
@Suite("AccountDeletionEffect against seeded data")
@MainActor
struct AccountDeletionEffectTests {
    /// Deleting a single client (Morgan Chen, `clientPersonID(1)` /
    /// `engagementID(1)` in the seeded fixture — see
    /// `MockData+Engagements.swift`) removes her engagement and everything
    /// scoped to it, and the `Person` record itself, while leaving Jordan
    /// Ellis (the professional) and every other client's engagement intact.
    @Test("deleting a client removes only that client's engagement-scoped data and their Person record")
    func deletingClientRemovesOnlyTheirData() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morganChen = try #require(people.first { $0.displayName == "Morgan Chen" })
        let engagementID = try #require(try await backend.engagements.fetchEngagements(forClient: morganChen.id).first?.id)

        // Sanity: this engagement genuinely has scoped data to delete before we assert it's gone.
        let sessionsBefore = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        let progressBefore = try await backend.progress.fetchEntries(forEngagement: engagementID)
        #expect(!sessionsBefore.isEmpty)
        #expect(!progressBefore.isEmpty)

        let jordanEllis = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let otherEngagementsBefore = try await backend.engagements.fetchEngagements(forProfessional: jordanEllis.id)
        let samPatelEngagement = try #require(otherEngagementsBefore.first { $0.id != engagementID })

        let summary = await AccountDeletionEffect.deleteAccount(personID: morganChen.id, backend: backend)

        #expect(summary.personDeleted)
        #expect(summary.engagementsDeleted == 1)
        #expect(summary.sessionsDeleted == sessionsBefore.count)
        #expect(summary.progressEntriesDeleted == progressBefore.count)
        #expect(summary.professionalProfileDeleted == false) // Morgan Chen never coached.

        // The client and their engagement are genuinely gone from the backend.
        let personAfter = try await backend.people.get(morganChen.id)
        #expect(personAfter == nil)
        let engagementAfter = try await backend.engagements.get(engagementID)
        #expect(engagementAfter == nil)
        let sessionsAfter = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        #expect(sessionsAfter.isEmpty)
        let progressAfter = try await backend.progress.fetchEntries(forEngagement: engagementID)
        #expect(progressAfter.isEmpty)

        // Jordan Ellis and every other client engagement are untouched.
        let jordanAfter = try await backend.people.get(jordanEllis.id)
        #expect(jordanAfter != nil)
        let samEngagementAfter = try await backend.engagements.get(samPatelEngagement.id)
        #expect(samEngagementAfter != nil)
    }

    /// Deleting the professional removes their authored programs,
    /// availability windows, and professional profile, plus every
    /// engagement they're a party to (and that engagement's scoped data) —
    /// then the `Person` record itself.
    @Test("deleting the professional removes their programs, availability, profile, engagements, and Person record")
    func deletingProfessionalRemovesTheirBusinessData() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let jordanEllis = try #require(people.first { $0.displayName == "Jordan Ellis" })

        let programsBefore = try await backend.programs.list(forAuthor: jordanEllis.id)
        let windowsBefore = try await backend.availability.windows(forProfessional: jordanEllis.id)
        let engagementsBefore = try await backend.engagements.fetchEngagements(forProfessional: jordanEllis.id)
        #expect(!programsBefore.isEmpty)
        #expect(!engagementsBefore.isEmpty)
        let profileBefore = try await backend.professionals.profile(forProfessional: jordanEllis.id)
        #expect(profileBefore != nil)

        let summary = await AccountDeletionEffect.deleteAccount(personID: jordanEllis.id, backend: backend)

        #expect(summary.personDeleted)
        #expect(summary.professionalProfileDeleted)
        #expect(summary.programsDeleted == programsBefore.count)
        #expect(summary.availabilityWindowsDeleted == windowsBefore.count)
        #expect(summary.engagementsDeleted == engagementsBefore.count)

        let personAfter = try await backend.people.get(jordanEllis.id)
        #expect(personAfter == nil)
        let profileAfter = try await backend.professionals.profile(forProfessional: jordanEllis.id)
        #expect(profileAfter == nil)
        let programsAfter = try await backend.programs.list(forAuthor: jordanEllis.id)
        #expect(programsAfter.isEmpty)
        let engagementsAfter = try await backend.engagements.fetchEngagements(forProfessional: jordanEllis.id)
        #expect(engagementsAfter.isEmpty)
    }

    /// Deleting a person with no engagements and no professional profile
    /// (a brand-new, unconnected `Person`) is a no-op sweep that still
    /// successfully deletes the `Person` record — never a crash or a stuck
    /// partial state.
    @Test("deleting a person with no data at all still deletes the Person record cleanly")
    func deletingPersonWithNoDataStillSucceeds() async throws {
        let backend = InMemoryStore.seeded()
        let newPerson = Person(id: Identifier(), displayName: "Nobody Yet", roles: [.consumer], goals: [])
        _ = try await backend.people.upsert(newPerson)

        let summary = await AccountDeletionEffect.deleteAccount(personID: newPerson.id, backend: backend)

        #expect(summary.personDeleted)
        #expect(summary.engagementsDeleted == 0)
        #expect(summary.professionalProfileDeleted == false)

        let personAfter = try await backend.people.get(newPerson.id)
        #expect(personAfter == nil)
    }

    /// Deleting an account that doesn't exist at all reports `personDeleted
    /// == false` rather than crashing or lying about success.
    @Test("deleting a nonexistent account reports failure, not a crash")
    func deletingNonexistentAccountReportsFailure() async {
        let backend = InMemoryStore.seeded()
        let summary = await AccountDeletionEffect.deleteAccount(personID: Identifier(), backend: backend)
        #expect(!summary.personDeleted)
    }
}
