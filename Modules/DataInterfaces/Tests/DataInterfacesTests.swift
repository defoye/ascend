import Domain
import Testing
@testable import DataInterfaces

@Suite("DataInterfaces protocol shape")
struct DataInterfacesTests {
    @Test("AuthState is Sendable/Hashable and distinguishes signedOut from signedIn")
    func authStateEquality() {
        let user = AuthenticatedUser(personID: Identifier<Person>(), displayName: "Test", email: "test@example.com")
        #expect(AuthState.signedOut == AuthState.signedOut)
        #expect(AuthState.signedIn(user) == AuthState.signedIn(user))
        #expect(AuthState.signedOut != AuthState.signedIn(user))
    }

    @Test("a minimal stub conforms to every repository protocol and composes into a Backend")
    func stubConformsToBackend() async throws {
        let backend: any Backend = StubBackend()

        let people = try await backend.people.list()
        let profiles = try await backend.professionals.listProfiles()
        let engagement = Engagement(
            id: Identifier(),
            clientID: Identifier(),
            professionalID: Identifier(),
            status: .pending,
            startedAt: nil,
            endedAt: nil
        )
        let upserted = try await backend.engagements.upsert(engagement)

        #expect(people.isEmpty)
        #expect(profiles.isEmpty)
        #expect(upserted == engagement)
    }

    @Test("stream-vending protocol methods produce an AsyncStream that can be iterated")
    func stubStreamsAreIterable() async {
        let backend: any Backend = StubBackend()
        var sawFinish = false
        for await _ in backend.messages.messages(in: Identifier()) {
            sawFinish = false
        }
        sawFinish = true
        #expect(sawFinish)
    }
}
