import DataInterfaces
import Domain
import InMemoryStore
import Testing

@testable import Ascend

/// `AppContainer.consumerPersonID` is what stood between the signed-in user
/// and the consumer (client) experience actually rendering their own data
/// (see docs/ROADMAP.md "Launch hardening" LH-1): a Release build must run
/// the consumer side as the signed-in user's own `personID`, while the
/// DEBUG `InMemoryStore.seeded()` composition must keep substituting the
/// hand-picked seeded demo client so the role-switch demo still works.
/// Tests always build Debug, so this exercises the DEBUG branch of
/// `AppContainer.makeBackend()` directly; the Release branch (`user.personID`)
/// is covered by the `init`'s default argument, which the DEBUG branch is
/// required to override explicitly.
@Suite("AppContainer consumerPersonID resolution")
@MainActor
struct AppContainerTests {
    @Test("the default resolver (as Release composes it) returns the signed-in user's own personID")
    func defaultResolverReturnsSignedInUsersOwnPersonID() {
        let backend = InMemoryStore.seeded()
        let container = AppContainer(backend: backend, paymentsMode: .free)
        let user = AuthenticatedUser(personID: Identifier<Person>(), displayName: "Taylor Reed", email: "taylor@example.com")

        #expect(container.consumerPersonID(user) == user.personID)
    }

    @Test("the DEBUG seeded-InMemoryStore composition substitutes the seeded demo client, not the signed-in user")
    func liveDebugCompositionSubstitutesSeededDemoClient() {
        let container = AppContainer.live()
        let signedInProfessional = AuthenticatedUser(personID: Identifier<Person>(), displayName: "Jordan Ellis", email: "jordan@example.com")

        let resolved = container.consumerPersonID(signedInProfessional)

        #expect(resolved == InMemoryStore.demoClientPersonID)
        #expect(resolved != signedInProfessional.personID)
    }
}
