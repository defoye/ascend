import DataInterfaces
import Domain
import Observation

/// View model for the shared `SettingsView`: the signed-in person's display
/// name/email, a sign-out action, and in-app account deletion. Reachable
/// from both `CoachProfileView` and `ConsumerMeView` (see docs/ROADMAP.md
/// Prompt 16) — the same view model and view serve either role, since
/// settings/deletion aren't role-specific.
@MainActor
@Observable
public final class SettingsViewModel {
    public private(set) var displayName = ""
    public private(set) var roles: Set<PersonRole> = []
    public private(set) var isLoading = false
    public private(set) var isSigningOut = false
    public private(set) var isDeleting = false
    public private(set) var isAddingRole = false
    public private(set) var errorMessage: String?
    public private(set) var deletionSummary: AccountDeletionEffect.Summary?

    private let backend: any Backend
    private let personID: Identifier<Person>

    public init(backend: any Backend, personID: Identifier<Person>) {
        self.backend = backend
        self.personID = personID
    }

    /// The one `PersonRole` this person doesn't yet hold, when they hold
    /// exactly one — the role Settings offers to add (see `addOtherRole`).
    /// `nil` for a both-role person (nothing to add) or before `load()` has
    /// populated `roles`.
    public var missingRole: PersonRole? {
        guard roles.count == 1 else { return nil }
        return PersonRole.allCases.first { !roles.contains($0) }
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let person = try await backend.people.get(personID) else {
                errorMessage = "Couldn't load your account. Try again."
                backend.analytics.track(.errorOccurred(context: .loadSettings))
                return
            }
            displayName = person.displayName
            roles = person.roles
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your account. Try again."
            backend.analytics.track(.errorOccurred(context: .loadSettings))
        }
    }

    /// Adds `missingRole` to this person's roles, turning a single-role
    /// person into a both-role person (see docs/PRODUCT.md "Roles"). The
    /// caller is responsible for re-resolving role gating afterward (see
    /// `RootView`/`RoleGating` in the App target) so the role switcher
    /// becomes available without requiring a reinstall.
    @discardableResult
    public func addOtherRole() async -> Bool {
        guard let missingRole else { return false }
        isAddingRole = true
        defer { isAddingRole = false }
        do {
            guard let person = try await backend.people.get(personID) else {
                errorMessage = "Couldn't update your account. Try again."
                return false
            }
            let updated = Person(
                id: person.id,
                displayName: person.displayName,
                roles: person.roles.union([missingRole]),
                goals: person.goals
            )
            let saved = try await backend.people.upsert(updated)
            roles = saved.roles
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Couldn't update your account. Try again."
            return false
        }
    }

    public func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await backend.auth.signOut()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't sign out. Try again."
        }
    }

    /// Runs `AccountDeletionEffect.deleteAccount`, then — once the data
    /// sweep succeeds (`personAnonymized`) — destroys the auth identity via
    /// `backend.auth.deleteAccount()` so the composition root's auth-state
    /// listener (`RootView`) drops back to the signed-out screen
    /// automatically rather than continuing to render a tab bar for a
    /// person whose data has already been scrubbed.
    public func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        backend.analytics.track(.accountDeletionRequested(personID: personID))
        let summary = await AccountDeletionEffect.deleteAccount(personID: personID, backend: backend)
        deletionSummary = summary

        guard summary.personAnonymized else {
            errorMessage = "Couldn't delete your account. Try again."
            backend.analytics.track(.errorOccurred(context: .deleteAccount))
            return
        }

        backend.analytics.track(.accountDeleted(personID: personID))

        do {
            try await backend.auth.deleteAccount()
            errorMessage = nil
        } catch {
            errorMessage = "Your data was removed but the sign-in credential couldn't be deleted. Contact support."
            backend.analytics.track(.errorOccurred(context: .deleteAccount))
            try? await backend.auth.signOut()
        }
    }
}
