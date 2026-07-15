import DataInterfaces
import Domain
import Foundation
import Observation

/// View model for the "Add client" flow: create a brand-new coaching
/// relationship, either by creating a lightweight new `Person` record or by
/// inviting/selecting an existing `.consumer` person who isn't already
/// engaged with this professional.
///
/// Depends only on `any Backend` (see docs/ARCHITECTURE.md).
@MainActor
@Observable
public final class AddClientViewModel {
    /// Which half of the add-client flow is active.
    public enum Mode: Sendable, Equatable {
        case newPerson
        case existingPerson
    }

    public var mode: Mode = .newPerson

    // New-person path.
    public var name = ""
    public var selectedGoalKind: GoalKind?

    // Existing-person path.
    public private(set) var existingCandidates: [Person] = []
    public var selectedExistingPersonID: Identifier<Person>?

    public private(set) var isSaving = false
    public private(set) var saveErrorMessage: String?

    private let backend: any Backend
    private let professionalID: Identifier<Person>
    private let clock: @Sendable () -> Date

    public init(
        backend: any Backend,
        professionalID: Identifier<Person>,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.backend = backend
        self.professionalID = professionalID
        self.clock = clock
    }

    /// Whether `save()` currently has enough input to proceed.
    public var isValid: Bool {
        switch mode {
        case .newPerson:
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .existingPerson:
            selectedExistingPersonID != nil
        }
    }

    /// Loads `.consumer` people who don't already have an engagement with
    /// this professional, for the "invite existing person" picker. Excludes
    /// the professional themselves — a both-role person (see
    /// docs/PRODUCT.md) can't be their own client.
    public func loadExistingCandidates() async {
        do {
            let people = try await backend.people.list()
            let engagements = try await backend.engagements.fetchEngagements(forProfessional: professionalID)
            let alreadyEngaged = Set(engagements.map(\.clientID))
            existingCandidates = people.filter {
                $0.roles.contains(.consumer) && $0.id != professionalID && !alreadyEngaged.contains($0.id)
            }
        } catch {
            existingCandidates = []
        }
    }

    /// Creates the new coaching relationship: a `Person` (for the new-person
    /// path) plus an `Engagement` linking the client to `professionalID`.
    /// Returns whether the save succeeded.
    @discardableResult
    public func save() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            let clientID = try await resolveClientID()
            let engagement = Engagement(
                id: Identifier(),
                clientID: clientID,
                professionalID: professionalID,
                status: .active,
                startedAt: clock(),
                endedAt: nil
            )
            _ = try await backend.engagements.upsert(engagement)
            saveErrorMessage = nil
            return true
        } catch {
            saveErrorMessage = "Couldn't add this client. Try again."
            return false
        }
    }

    private func resolveClientID() async throws -> Identifier<Person> {
        switch mode {
        case .newPerson:
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let goals: [Goal] = selectedGoalKind.map { [Goal(id: Identifier(), kind: $0, metric: nil, target: nil, deadline: nil)] } ?? []
            let person = Person(id: Identifier(), displayName: trimmedName, roles: [.consumer], goals: goals)
            let saved = try await backend.people.upsert(person)
            return saved.id
        case .existingPerson:
            guard let selectedExistingPersonID else {
                throw AddClientError.noExistingPersonSelected
            }
            return selectedExistingPersonID
        }
    }
}

enum AddClientError: Error {
    case noExistingPersonSelected
}
