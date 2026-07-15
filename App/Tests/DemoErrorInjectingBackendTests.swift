import DataInterfaces
import Domain
import InMemoryStore
import Testing

@testable import Ascend

@Suite("DemoErrorInjectingBackend")
struct DemoErrorInjectingBackendTests {
    @Test("every one-shot repository read throws")
    func readsThrow() async throws {
        let backend = DemoErrorInjectingBackend(wrapped: InMemoryStore.seeded())
        await #expect(throws: DemoErrorInjectingBackend.SimulatedError.self) {
            _ = try await backend.people.list()
        }
    }

    @Test("payment gateway charge throws instead of silently succeeding")
    func paymentGatewayThrows() async throws {
        let backend = DemoErrorInjectingBackend(wrapped: InMemoryStore.seeded())
        await #expect(throws: DemoErrorInjectingBackend.SimulatedError.self) {
            _ = try await backend.paymentGateway.charge(engagementID: Identifier(), amountCents: 1_000, currency: "USD")
        }
    }

    @Test("live AsyncStream reads finish empty instead of hanging or throwing")
    func streamsFinishEmpty() async {
        let backend = DemoErrorInjectingBackend(wrapped: InMemoryStore.seeded())
        var values: [[Message]] = []
        for await value in backend.messages.messages(in: Identifier()) {
            values.append(value)
        }
        #expect(values.isEmpty)
    }

    @Test("auth passes through to the wrapped backend untouched")
    func authPassesThrough() async {
        let backend = DemoErrorInjectingBackend(wrapped: InMemoryStore.seeded())
        var sawSignedIn = false
        for await state in backend.auth.currentAuth {
            if case .signedIn = state { sawSignedIn = true }
            break
        }
        #expect(sawSignedIn)
    }
}
