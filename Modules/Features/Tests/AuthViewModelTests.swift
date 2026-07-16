import DataInterfaces
import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("AuthViewModel")
@MainActor
struct AuthViewModelTests {
    @Test("sign-up creates a Person with exactly the chosen role and transitions auth state to signed in")
    func signUpCoachOnlyCreatesPersonWithChosenRoleAndSignsIn() async throws {
        let backend = InMemoryBackend()
        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signUp
        viewModel.displayName = "New Coach"
        viewModel.email = "new-coach@example.com"
        viewModel.password = "supersecret"
        viewModel.roleChoice = .coach

        await viewModel.submit()

        #expect(viewModel.errorMessage == nil)
        let user = try await signedInUser(backend)
        let person = try await backend.people.get(user.personID)
        #expect(person?.roles == [.professional])
        #expect(person?.displayName == "New Coach")
    }

    @Test("sign-up with 'Both' creates a Person holding both roles")
    func signUpBothCreatesPersonWithBothRoles() async throws {
        let backend = InMemoryBackend()
        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signUp
        viewModel.displayName = "Dual Role"
        viewModel.email = "dual@example.com"
        viewModel.password = "supersecret"
        viewModel.roleChoice = .both

        await viewModel.submit()

        #expect(viewModel.errorMessage == nil)
        let user = try await signedInUser(backend)
        let person = try await backend.people.get(user.personID)
        #expect(person?.roles == [.professional, .consumer])
    }

    @Test("sign-up rejects invalid input locally without registering a Person")
    func signUpValidatesFieldsLocally() async throws {
        let backend = InMemoryBackend()
        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signUp
        viewModel.displayName = ""
        viewModel.email = "not-an-email"
        viewModel.password = "short"

        await viewModel.submit()

        #expect(viewModel.displayNameError != nil)
        #expect(viewModel.emailError != nil)
        #expect(viewModel.passwordError != nil)
        let registered = try await backend.people.list()
        #expect(registered.isEmpty)
    }

    @Test("sign-in success transitions auth state to signed in")
    func signInSuccessTransitionsAuthState() async throws {
        let backend = InMemoryBackend()
        try await backend.signUp(email: "existing@example.com", password: "supersecret", displayName: "Existing", roles: [.consumer])
        try await backend.signOut()

        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signIn
        viewModel.email = "existing@example.com"
        viewModel.password = "supersecret"

        await viewModel.submit()

        #expect(viewModel.errorMessage == nil)
        _ = try await signedInUser(backend)
    }

    @Test("sign-in failure surfaces an error message and leaves auth state signed out")
    func signInFailureSurfacesError() async throws {
        let backend = InMemoryBackend()
        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signIn
        viewModel.email = "nobody@example.com"
        viewModel.password = "supersecret"

        await viewModel.submit()

        #expect(viewModel.errorMessage != nil)
        var iterator = backend.currentAuth.makeAsyncIterator()
        let state = await iterator.next()
        #expect(state == .signedOut)
    }

    @Test("sign-up requiring email confirmation shows a notice, switches to sign-in mode, and leaves errorMessage nil")
    func signUpConfirmationRequiredShowsNotice() async throws {
        let gateway = ScriptedAuthGateway(signUpOutcome: .confirmationRequired)
        let viewModel = AuthViewModel(auth: gateway)
        viewModel.mode = .signUp
        viewModel.displayName = "New Coach"
        viewModel.email = "  pending@example.com  "
        viewModel.password = "supersecret"
        viewModel.roleChoice = .coach

        await viewModel.submit()

        #expect(viewModel.confirmationNoticeEmail == "pending@example.com")
        #expect(viewModel.mode == .signIn)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("sign-up that signs in immediately leaves confirmationNoticeEmail nil")
    func signUpSignedInLeavesNoNotice() async throws {
        // Existing InMemoryBackend-backed sign-up tests above already assert
        // `errorMessage == nil` after a `.signedIn` sign-up; this adds an
        // explicit check on the new property using the same real backend.
        let backend = InMemoryBackend()
        let viewModel = AuthViewModel(auth: backend)
        viewModel.mode = .signUp
        viewModel.displayName = "New Coach"
        viewModel.email = "signedin@example.com"
        viewModel.password = "supersecret"
        viewModel.roleChoice = .coach

        await viewModel.submit()

        #expect(viewModel.confirmationNoticeEmail == nil)
    }

    @Test("sign-in rejected for an unconfirmed email surfaces the specific confirmation message")
    func signInEmailNotConfirmedSurfacesSpecificMessage() async throws {
        let gateway = ScriptedAuthGateway(signInError: AuthGatewayError.emailNotConfirmed)
        let viewModel = AuthViewModel(auth: gateway)
        viewModel.mode = .signIn
        viewModel.email = "pending@example.com"
        viewModel.password = "supersecret"

        await viewModel.submit()

        #expect(viewModel.errorMessage == "Confirm your email first — check your inbox for the link we sent to pending@example.com.")
    }

    @Test("a fresh submit() clears a prior confirmation notice")
    func submitClearsPriorConfirmationNotice() async throws {
        let gateway = ScriptedAuthGateway(signUpOutcome: .confirmationRequired)
        let viewModel = AuthViewModel(auth: gateway)
        viewModel.mode = .signUp
        viewModel.displayName = "New Coach"
        viewModel.email = "pending@example.com"
        viewModel.password = "supersecret"
        viewModel.roleChoice = .coach
        await viewModel.submit()
        #expect(viewModel.confirmationNoticeEmail != nil)

        viewModel.mode = .signIn
        viewModel.email = "someone-else@example.com"
        viewModel.password = "supersecret"
        await viewModel.submit()

        #expect(viewModel.confirmationNoticeEmail == nil)
    }

    /// A freshly subscribed `currentAuth` immediately yields the current
    /// state as its first element (see `StreamRegistry.register`), so this
    /// reads the *current* auth state without any internal test-only access
    /// into `InMemoryBackend` — exactly what `RootView` observes in
    /// production.
    private func signedInUser(_ backend: InMemoryBackend) async throws -> AuthenticatedUser {
        var iterator = backend.currentAuth.makeAsyncIterator()
        guard case let .signedIn(user) = await iterator.next() else {
            throw TestError.notSignedIn
        }
        return user
    }

    private enum TestError: Error {
        case notSignedIn
    }
}

/// A test-local `AuthGateway` that returns/throws exactly what it's
/// configured with, for outcomes `InMemoryBackend` can't be made to produce
/// (`.confirmationRequired`, `AuthGatewayError.emailNotConfirmed`).
private struct ScriptedAuthGateway: AuthGateway {
    var signUpOutcome: SignUpOutcome = .signedIn
    var signInError: Error?

    var currentAuth: AsyncStream<AuthState> { AsyncStream { $0.finish() } }

    func signIn(email: String, password: String) async throws {
        if let signInError { throw signInError }
    }

    func signUp(email: String, password: String, displayName: String, roles: Set<PersonRole>) async throws -> SignUpOutcome {
        signUpOutcome
    }

    func signOut() async throws {}
    func deleteAccount() async throws {}
}
