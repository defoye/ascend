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
    public private(set) var isLoading = false
    public private(set) var isSigningOut = false
    public private(set) var isDeleting = false
    public private(set) var errorMessage: String?
    public private(set) var deletionSummary: AccountDeletionEffect.Summary?

    private let backend: any Backend
    private let personID: Identifier<Person>

    public init(backend: any Backend, personID: Identifier<Person>) {
        self.backend = backend
        self.personID = personID
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            displayName = try await backend.people.get(personID)?.displayName ?? ""
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load your account. Try again."
            backend.analytics.track(.errorOccurred(context: .loadSettings))
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

    /// Runs `AccountDeletionEffect.deleteAccount`, then signs out on success
    /// so the composition root's auth-state listener (`RootView`) drops back
    /// to the signed-out screen automatically rather than continuing to
    /// render a tab bar for a person who no longer exists.
    public func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        backend.analytics.track(.accountDeletionRequested(personID: personID))
        let summary = await AccountDeletionEffect.deleteAccount(personID: personID, backend: backend)
        deletionSummary = summary

        guard summary.personDeleted else {
            errorMessage = "Couldn't delete your account. Try again."
            backend.analytics.track(.errorOccurred(context: .deleteAccount))
            return
        }

        errorMessage = nil
        backend.analytics.track(.accountDeleted(personID: personID))
        try? await backend.auth.signOut()
    }
}
