import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the program builder: create a brand-new `Program` or edit
/// an existing one via a mutable `ProgramDraft`, then persist through
/// `ProgramRepository.upsert(_:)`.
///
/// Week/workout/prescription mutation is expressed as small, focused methods
/// keyed by stable `Identifier`s (not raw array indices) so a pushed
/// week/workout screen stays correct even if the parent list is edited
/// elsewhere. The underlying add/duplicate/delete/reorder logic itself lives
/// in `ProgramDraftOperations`, kept pure and directly testable.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ProgramBuilderViewModel {
    public var draft: ProgramDraft
    public let isNewProgram: Bool
    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?
    public private(set) var exerciseLibrary: [Exercise] = []

    private let backend: any Backend
    private let professionalID: Identifier<Person>

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        existingProgram: Program? = nil
    ) {
        self.backend = backend
        self.professionalID = professionalID
        if let existingProgram {
            draft = ProgramDraft(program: existingProgram)
            isNewProgram = false
        } else {
            draft = ProgramDraft(authorID: professionalID)
            isNewProgram = true
        }
    }

    public var isValid: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Loads the exercise library (every distinct exercise used across the
    /// coach's existing programs) for the exercise picker.
    public func loadExerciseLibrary() async {
        do {
            let programs = try await backend.programs.list(forAuthor: professionalID)
            exerciseLibrary = ExerciseLibrary.aggregate(from: programs)
        } catch {
            exerciseLibrary = []
        }
    }

    /// Builds the immutable `Program` from `draft` and persists it.
    @discardableResult
    public func save() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await backend.programs.upsert(draft.makeProgram())
            saveErrorMessage = nil
            return true
        } catch {
            saveErrorMessage = "Couldn't save this program. Try again."
            return false
        }
    }

    // MARK: - Week lookups & operations

    public func week(withID id: Identifier<ProgramWeek>) -> ProgramWeekDraft? {
        draft.weeks.first { $0.id == id }
    }

    public func weekIndex(withID id: Identifier<ProgramWeek>) -> Int? {
        draft.weeks.firstIndex { $0.id == id }
    }

    public func addWeek() {
        draft.weeks = ProgramDraftOperations.addWeek(draft.weeks)
    }

    public func duplicateWeek(at index: Int) {
        draft.weeks = ProgramDraftOperations.duplicateWeek(draft.weeks, at: index)
    }

    public func deleteWeeks(at offsets: IndexSet) {
        draft.weeks = ProgramDraftOperations.delete(draft.weeks, at: offsets)
    }

    public func moveWeeks(from source: IndexSet, to destination: Int) {
        draft.weeks = ProgramDraftOperations.move(draft.weeks, from: source, to: destination)
    }
}
