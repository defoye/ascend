import DataInterfaces
import Domain
import Foundation

/// Cross-role "something new" detection (see docs/design/DESIGN_SPEC.md §4
/// "Role switch"): for a person who holds both `PersonRole`s, computes the
/// latest **inbound** activity timestamp on each side of the app — activity
/// the other party generated, not the person's own actions — so the App
/// composition root can light a quiet dot rather than a loud unread count.
///
/// Deliberately simple and best-effort: it walks the engagements a role
/// participates in and takes the newest of a handful of existing Domain
/// timestamps. It never mutates anything and only depends on
/// `DataInterfaces` + `Domain`, so it lives in `Features` (see CLAUDE.md's
/// dependency rule) — the App target wires it against a concrete `Backend`
/// and a persisted "last visited" date per role.
public enum RoleActivitySummary {
    /// Latest inbound activity for the **professional** side of a person's
    /// engagements: messages from someone other than the professional,
    /// client-logged progress entries, and session scheduling activity.
    public static func professionalInboundActivity(
        backend: any Backend,
        professionalID: Identifier<Person>
    ) async -> Date? {
        let engagements = (try? await backend.engagements.fetchEngagements(forProfessional: professionalID)) ?? []
        var latest: Date?
        for engagement in engagements {
            let messages = (try? await backend.messages.fetchMessages(forEngagement: engagement.id)) ?? []
            for message in messages where message.authorID != professionalID {
                latest = newer(latest, message.sentAt)
            }

            let progress = (try? await backend.progress.fetchEntries(forEngagement: engagement.id)) ?? []
            for entry in progress where entry.source != .coachRecorded {
                latest = newer(latest, entry.recordedAt)
            }

            let sessions = (try? await backend.sessions.fetchSessions(forEngagement: engagement.id)) ?? []
            for session in sessions {
                latest = newer(latest, session.scheduledAt)
            }
        }
        return latest
    }

    /// Latest inbound activity for the **consumer** side of a person's
    /// engagements: messages from the coach, newly assigned programs, and
    /// newly scheduled sessions.
    public static func consumerInboundActivity(
        backend: any Backend,
        clientID: Identifier<Person>
    ) async -> Date? {
        let engagements = (try? await backend.engagements.fetchEngagements(forClient: clientID)) ?? []
        var latest: Date?
        for engagement in engagements {
            let messages = (try? await backend.messages.fetchMessages(forEngagement: engagement.id)) ?? []
            for message in messages where message.authorID != clientID {
                latest = newer(latest, message.sentAt)
            }

            let assignments = (try? await backend.programs.assignments(forEngagement: engagement.id)) ?? []
            for assignment in assignments {
                latest = newer(latest, assignment.assignedAt)
            }

            let sessions = (try? await backend.sessions.fetchSessions(forEngagement: engagement.id)) ?? []
            for session in sessions {
                latest = newer(latest, session.scheduledAt)
            }
        }
        return latest
    }

    /// Whether `latestInboundActivity` is newer than `lastVisited` — the
    /// pure comparison behind the cross-role dot. No activity means no dot;
    /// activity with no recorded visit yet means a dot (never visited).
    public static func hasUpdates(latestInboundActivity: Date?, sinceLastVisited lastVisited: Date?) -> Bool {
        guard let latestInboundActivity else { return false }
        guard let lastVisited else { return true }
        return latestInboundActivity > lastVisited
    }

    private static func newer(_ current: Date?, _ candidate: Date) -> Date {
        guard let current else { return candidate }
        return max(current, candidate)
    }
}
