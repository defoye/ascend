import DataInterfaces
import Domain
import Foundation

/// Pure orchestration of "delete my account": ends every engagement the
/// person is a party to, removes their own private/authored data, and
/// anonymizes their `Person` record — entirely through `Backend` protocols
/// (see docs/ARCHITECTURE.md) — works unchanged against `InMemoryStore`
/// today and any future adapter, and is unit-testable without touching
/// SwiftUI (see `AccountDeletionEffectTests`).
///
/// ## Why the `Person` row is anonymized, never deleted
///
/// `engagements.client_id` and `engagements.professional_id` both carry
/// `on delete cascade` back to `people`
/// (`Server/supabase/migrations/20260714120200_engagements.sql`), and every
/// engagement-scoped table — sessions, progress entries, progress photos,
/// payments, coach notes — cascades off `engagements` in turn. Deleting the
/// `people` row would therefore delete every engagement the person was ever
/// part of, including the **other party's** sessions, progress history, and
/// payment records, purely as a side effect of Postgres foreign keys — no
/// amount of care in this Swift code can prevent that once the row is gone.
/// So the `Person` record survives, scrubbed of anything identifying
/// (`displayName`, `roles`, `goals`), while engagements are *ended*, not
/// deleted, so the coaching history stays intact for the other party. Do
/// not "fix" this back to a `people.delete` call — that reintroduces the
/// data-loss bug this type exists to close.
///
/// ## Scope
///
/// - Every engagement the person is a party to (as client or professional)
///   that isn't already `.ended`/`.completed` is ended (`status: .ended`,
///   `endedAt: now`). Sessions, progress entries, progress photos, and
///   payments on those engagements are left untouched — they belong to the
///   coaching relationship, not solely to the deleting person, and the
///   other party is entitled to keep their history.
/// - Coach notes are deleted only for engagements where the deleting person
///   is the *professional* — notes are coach-private authored data (see
///   docs/DATA_MODEL.md "Coach notes"). A deleting client never touches the
///   coach's notes.
/// - If the person coaches, their authored programs, availability windows,
///   and professional profile are deleted, as before.
///
/// Message history is deliberately left in place: `MessageRepository` is
/// stream-first with no delete operation (see docs/DATA_MODEL.md) — a
/// production backend would redact/anonymize the deleted party's messages
/// rather than mutate what's otherwise an immutable, append-only log shared
/// with the other party in the conversation.
public enum AccountDeletionEffect {
    /// What got removed or changed, for confirmation UI and tests. Every
    /// field is a count (or a flag for the two singular outcomes), never
    /// data itself.
    public struct Summary: Sendable, Equatable {
        public var engagementsEnded = 0
        public var notesDeleted = 0
        public var programsDeleted = 0
        public var availabilityWindowsDeleted = 0
        public var professionalProfileDeleted = false
        public var personAnonymized = false

        public init() {}
    }

    /// Ends every engagement `personID` is a party to, deletes their private
    /// authored data, and anonymizes their `Person` record (see the type's
    /// doc comment for why anonymize rather than delete). Best-effort per
    /// repository call: a failure on one record doesn't stop the sweep, so a
    /// partial backend failure never leaves the account half-processed —
    /// `Summary.personAnonymized` tells the caller whether the step that
    /// matters (scrubbing the account) actually happened.
    ///
    /// - Parameter clock: Supplies "now" for `endedAt`, matching the
    ///   codebase's clock-injection convention (e.g. `TodayViewModel`)
    ///   rather than hardcoding `Date()`.
    public static func deleteAccount(
        personID: Identifier<Person>,
        backend: any Backend,
        clock: @Sendable () -> Date = { Date() }
    ) async -> Summary {
        var summary = Summary()

        let clientEngagements = (try? await backend.engagements.fetchEngagements(forClient: personID)) ?? []
        let professionalEngagements = (try? await backend.engagements.fetchEngagements(forProfessional: personID)) ?? []

        for engagement in professionalEngagements {
            let notes = (try? await backend.notes.notes(forEngagement: engagement.id)) ?? []
            for note in notes where (try? await backend.notes.delete(note.id)) != nil {
                summary.notesDeleted += 1
            }
        }

        var seenEngagementIDs = Set<Identifier<Engagement>>()
        for engagement in clientEngagements + professionalEngagements {
            guard seenEngagementIDs.insert(engagement.id).inserted else { continue }
            guard engagement.status != .ended, engagement.status != .completed else { continue }
            let ended = Engagement(
                id: engagement.id,
                clientID: engagement.clientID,
                professionalID: engagement.professionalID,
                status: .ended,
                startedAt: engagement.startedAt,
                endedAt: clock()
            )
            if (try? await backend.engagements.upsert(ended)) != nil {
                summary.engagementsEnded += 1
            }
        }

        if let profile = try? await backend.professionals.profile(forProfessional: personID) {
            await deleteProfessionalScopedData(personID: personID, backend: backend, summary: &summary)
            if (try? await backend.professionals.delete(profile.id)) != nil {
                summary.professionalProfileDeleted = true
            }
        }

        if let person = try? await backend.people.get(personID) {
            let anonymized = Person(id: person.id, displayName: "Deleted user", roles: [], goals: [])
            if (try? await backend.people.upsert(anonymized)) != nil {
                summary.personAnonymized = true
            }
        }

        return summary
    }

    private static func deleteProfessionalScopedData(
        personID: Identifier<Person>,
        backend: any Backend,
        summary: inout Summary
    ) async {
        let programs = (try? await backend.programs.list(forAuthor: personID)) ?? []
        for program in programs where (try? await backend.programs.delete(program.id)) != nil {
            summary.programsDeleted += 1
        }

        let windows = (try? await backend.availability.windows(forProfessional: personID)) ?? []
        for window in windows where (try? await backend.availability.delete(window.id)) != nil {
            summary.availabilityWindowsDeleted += 1
        }
    }
}
