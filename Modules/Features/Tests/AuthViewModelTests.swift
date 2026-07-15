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
