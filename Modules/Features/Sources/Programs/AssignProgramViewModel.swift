import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for assigning (or reassigning) one of the coach's programs to
/// a client engagement, with a start date.
///
/// "Reassign" is just another assignment: `ProgramRepository.assignments(
/// forEngagement:)` is sorted by `assignedAt` ascending, so the most recently
/// assigned program is always the current one (see `ClientDetailViewModel.
/// load()`).
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class AssignProgramViewModel {
    public private(set) var programs: [Program] = []
    public var selectedProgramID: Identifier<Program>?
    public var startDate: Date
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let engagementID: Identifier<Engagement>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        engagementID: Identifier<Engagement>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.engagementID = engagementID
        self.clock = clock
        startDate = clock()
    }

    public var isValid: Bool { selectedProgramID != nil }

    /// Loads the coach's programs and, if nothing is selected yet, defaults
    /// the selection to the first (alphabetically) so the picker never opens
    /// empty when programs exist.
    public func load() async {
        do {
            programs = try await backend.programs.list(forAuthor: professionalID)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            if selectedProgramID == nil {
                selectedProgramID = programs.first?.id
            }
        } catch {
            programs = []
        }
    }

    @discardableResult
    public func assign() async -> Bool {
        guard let selectedProgramID else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await backend.programs.assign(
                ProgramAssignment(
                    id: Identifier(),
                    programID: selectedProgramID,
                    engagementID: engagementID,
                    assignedAt: clock(),
                    startDate: startDate
                )
            )
            saveErrorMessage = nil
            return true
        } catch {
            saveErrorMessage = "Couldn't assign this program. Try again."
            return false
        }
    }
}
