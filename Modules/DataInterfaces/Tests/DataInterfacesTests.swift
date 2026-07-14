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

@Suite("PaymentsMode / NoOpPaymentGateway")
struct PaymentsModeTests {
    @Test("PaymentsMode has exactly the two documented cases")
    func paymentsModeCases() {
        #expect(PaymentsMode.allCases == [.free, .live])
    }

    @Test("NoOpPaymentGateway throws for every operation — it never fabricates a successful charge")
    func noOpGatewayAlwaysThrows() async {
        let gateway = NoOpPaymentGateway()

        await #expect(throws: NoOpPaymentGateway.GatewayError.paymentsNotEnabled) {
            _ = try await gateway.charge(engagementID: Identifier(), amountCents: 1_000, currency: "USD")
        }
        await #expect(throws: NoOpPaymentGateway.GatewayError.paymentsNotEnabled) {
            _ = try await gateway.refund(paymentID: Identifier())
        }
    }
}
