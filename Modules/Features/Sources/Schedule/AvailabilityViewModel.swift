import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's weekly recurring availability editor: add,
/// edit, and delete `AvailabilityWindow`s.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class AvailabilityViewModel {
    public private(set) var windows: [AvailabilityWindow] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(backend: any Backend, professionalID: Identifier<Person>) {
        self.backend = backend
        self.professionalID = professionalID
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            windows = try await backend.availability.windows(forProfessional: professionalID)
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your availability. Pull to refresh to try again."
        }
    }

    /// Adds a new weekly window.
    public func addWindow(weekday: Int, startMinute: Int, endMinute: Int) async {
        let window = AvailabilityWindow(
            id: Identifier(),
            professionalID: professionalID,
            weekday: weekday,
            startMinute: startMinute,
            endMinute: endMinute
        )
        await save(window)
    }

    /// Rewrites an existing window's times/weekday, preserving its `id`.
    public func updateWindow(_ window: AvailabilityWindow, weekday: Int, startMinute: Int, endMinute: Int) async {
        let updated = AvailabilityWindow(
            id: window.id,
            professionalID: professionalID,
            weekday: weekday,
            startMinute: startMinute,
            endMinute: endMinute
        )
        await save(updated)
    }

    public func deleteWindow(_ id: Identifier<AvailabilityWindow>) async {
        do {
            try await backend.availability.delete(id)
            windows.removeAll { $0.id == id }
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Couldn't delete this window. Try again."
        }
    }

    private func save(_ window: AvailabilityWindow) async {
        guard window.isValid else {
            saveErrorMessage = "End time must be after start time."
            return
        }
        do {
            let saved = try await backend.availability.upsert(window)
            if let index = windows.firstIndex(where: { $0.id == saved.id }) {
                windows[index] = saved
            } else {
                windows.append(saved)
            }
            windows.sort { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Couldn't save this window. Try again."
        }
    }
}
