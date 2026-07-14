import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for booking a new session: pick one of the coach's
/// (non-ended, non-completed) client engagements and a date/time, then
/// create it as a fresh `.scheduled` `Session` (booking **is** the
/// confirmation step — see `SessionTransitions`).
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md) plus a clock and
/// an injected `SessionReminderScheduling` — booking schedules a local
/// reminder for the new session.
@MainActor
@Observable
public final class BookSessionViewModel {
    public private(set) var engagementOptions: [BookableEngagement] = []
    public var selectedEngagementID: Identifier<Engagement>?
    public var scheduledAt: Date
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date
    private let reminders: any SessionReminderScheduling

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() },
        reminders: any SessionReminderScheduling = LiveSessionReminderScheduler()
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
        self.reminders = reminders
        scheduledAt = clock()
    }

    public var isValid: Bool { selectedEngagementID != nil }

    /// Loads the coach's bookable engagements (any status other than
    /// `.ended`/`.completed`) and defaults the selection to the first
    /// (alphabetically by client name) so the picker never opens empty.
    public func load() async {
        do {
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            var options: [BookableEngagement] = []
            for engagement in engagements where engagement.status != .ended && engagement.status != .completed {
                let client = try await backend.people.get(engagement.clientID)
                options.append(BookableEngagement(engagementID: engagement.id, clientName: client?.displayName ?? "Client"))
            }
            engagementOptions = options.sorted { $0.clientName.localizedCaseInsensitiveCompare($1.clientName) == .orderedAscending }
            if selectedEngagementID == nil {
                selectedEngagementID = engagementOptions.first?.engagementID
            }
        } catch {
            engagementOptions = []
        }
    }

    /// Creates a new `.scheduled` `Session` via `SessionRepository.upsert(_:)`
    /// and schedules a local reminder for it. Returns the saved session on
    /// success.
    @discardableResult
    public func book() async -> Session? {
        guard let selectedEngagementID else { return nil }
        isSaving = true
        defer { isSaving = false }

        let session = Session(id: Identifier(), engagementID: selectedEngagementID, scheduledAt: scheduledAt, status: .scheduled)
        do {
            let saved = try await backend.sessions.upsert(session)
            let clientName = engagementOptions.first { $0.engagementID == selectedEngagementID }?.clientName ?? "Client"
            await reminders.scheduleReminder(for: saved, clientName: clientName)
            saveErrorMessage = nil
            return saved
        } catch {
            saveErrorMessage = "Couldn't book this session. Try again."
            return nil
        }
    }
}
