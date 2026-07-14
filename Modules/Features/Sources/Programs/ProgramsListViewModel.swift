import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the coach's Programs tab: every program the professional
/// has authored, alphabetized by title.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class ProgramsListViewModel {
    public private(set) var programs: [Program] = []
    public private(set) var isLoading = false
    public private(set) var loadErrorMessage: String?

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
            programs = try await backend.programs.list(forAuthor: professionalID)
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            loadErrorMessage = nil
        } catch {
            loadErrorMessage = "Couldn't load your programs. Pull to refresh to try again."
        }
    }
}

extension Program {
    /// Total workouts across every week — a quick summary stat for program
    /// rows.
    public var workoutCount: Int {
        weeks.reduce(0) { $0 + $1.workouts.count }
    }
}
