import DataInterfaces
import Domain

/// Pure orchestration of "delete my account": walks every repository that
/// holds data scoped to a `Person` and removes it, entirely through
/// `Backend` protocols (see docs/ARCHITECTURE.md) — works unchanged against
/// `InMemoryStore` today and any future adapter, and is unit-testable
/// without touching SwiftUI (see `AccountDeletionEffectTests`).
///
/// Scope: every engagement the person is a party to (as client or
/// professional) and everything scoped to those engagements — sessions,
/// progress entries, progress photos, coach notes, payments — plus, if the
/// person coaches, their authored programs, availability windows, and
/// professional profile. The `Person` record itself is deleted last, so a
/// caller can always tell deletion completed by checking
/// `Summary.personDeleted`.
///
/// Message history is deliberately left in place: `MessageRepository` is
/// stream-first with no delete operation (see docs/DATA_MODEL.md) — a
/// production backend would redact/anonymize the deleted party's messages
/// rather than mutate what's otherwise an immutable, append-only log shared
/// with the other party in the conversation. That's a real product decision
/// or a Prompt 13+ `SupabaseBackend` concern, not something this mock-data
/// effect can respect against a protocol with no delete method to call.
public enum AccountDeletionEffect {
    /// What got removed, for confirmation UI and tests. Every field is a
    /// count (or a flag for the two singular records), never data itself.
    public struct Summary: Sendable, Equatable {
        public var engagementsDeleted = 0
        public var sessionsDeleted = 0
        public var progressEntriesDeleted = 0
        public var progressPhotosDeleted = 0
        public var notesDeleted = 0
        public var paymentsDeleted = 0
        public var programsDeleted = 0
        public var availabilityWindowsDeleted = 0
        public var professionalProfileDeleted = false
        public var personDeleted = false

        public init() {}
    }

    /// Deletes every piece of `personID`'s data reachable through `backend`,
    /// then the `Person` record itself. Best-effort per repository call: a
    /// failure deleting one record doesn't stop the sweep, so a partial
    /// backend failure never leaves the account half-deleted-and-stuck —
    /// `Summary.personDeleted` tells the caller whether the one record that
    /// matters (the account itself) actually went away.
    public static func deleteAccount(personID: Identifier<Person>, backend: any Backend) async -> Summary {
        var summary = Summary()

        let clientEngagements = (try? await backend.engagements.fetchEngagements(forClient: personID)) ?? []
        let professionalEngagements = (try? await backend.engagements.fetchEngagements(forProfessional: personID)) ?? []
        var engagementIDs = Set(clientEngagements.map(\.id))
        engagementIDs.formUnion(professionalEngagements.map(\.id))

        for engagementID in engagementIDs {
            await deleteEngagementScopedData(engagementID, backend: backend, summary: &summary)
        }
        for engagementID in engagementIDs where (try? await backend.engagements.delete(engagementID)) != nil {
            summary.engagementsDeleted += 1
        }

        if let profile = try? await backend.professionals.profile(forProfessional: personID) {
            await deleteProfessionalScopedData(personID: personID, backend: backend, summary: &summary)
            if (try? await backend.professionals.delete(profile.id)) != nil {
                summary.professionalProfileDeleted = true
            }
        }

        if (try? await backend.people.delete(personID)) != nil {
            summary.personDeleted = true
        }

        return summary
    }

    private static func deleteEngagementScopedData(
        _ engagementID: Identifier<Engagement>,
        backend: any Backend,
        summary: inout Summary
    ) async {
        let sessions = (try? await backend.sessions.fetchSessions(forEngagement: engagementID)) ?? []
        for session in sessions where (try? await backend.sessions.delete(session.id)) != nil {
            summary.sessionsDeleted += 1
        }

        let entries = (try? await backend.progress.fetchEntries(forEngagement: engagementID)) ?? []
        for entry in entries where (try? await backend.progress.delete(entry.id)) != nil {
            summary.progressEntriesDeleted += 1
        }

        let photos = (try? await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)) ?? []
        for photo in photos where (try? await backend.progressPhotos.delete(photo.id)) != nil {
            summary.progressPhotosDeleted += 1
        }

        let notes = (try? await backend.notes.notes(forEngagement: engagementID)) ?? []
        for note in notes where (try? await backend.notes.delete(note.id)) != nil {
            summary.notesDeleted += 1
        }

        let payments = (try? await backend.payments.payments(forEngagement: engagementID)) ?? []
        for payment in payments where (try? await backend.payments.delete(payment.id)) != nil {
            summary.paymentsDeleted += 1
        }
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
