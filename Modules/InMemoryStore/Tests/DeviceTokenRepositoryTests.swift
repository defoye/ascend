import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

@Suite("InMemoryBackend as DeviceTokenRepository")
struct DeviceTokenRepositoryTests {
    @Test("register while signed in records the signed-in person's id")
    func registerWhileSignedInRecordsPerson() async throws {
        let backend = InMemoryBackend.seeded()
        let people = try await backend.people.list()
        let jordanEllis = try #require(people.first { $0.displayName == "Jordan Ellis" })

        try await backend.deviceTokens.register(token: "tok-signed-in", platform: "ios")

        let registered = await backend.registeredDeviceTokens()
        #expect(registered["tok-signed-in"] == jordanEllis.id)
    }

    @Test("register while signed out is a no-op")
    func registerWhileSignedOutIsNoOp() async throws {
        let backend = InMemoryBackend()

        try await backend.deviceTokens.register(token: "tok-signed-out", platform: "ios")

        let registered = await backend.registeredDeviceTokens()
        #expect(registered.isEmpty)
    }

    @Test("unregister removes a previously registered token")
    func unregisterRemovesToken() async throws {
        let backend = InMemoryBackend.seeded()
        try await backend.deviceTokens.register(token: "tok-to-remove", platform: "ios")
        let registeredBefore = await backend.registeredDeviceTokens()
        #expect(registeredBefore["tok-to-remove"] != nil)

        try await backend.deviceTokens.unregister(token: "tok-to-remove")

        let registeredAfter = await backend.registeredDeviceTokens()
        #expect(registeredAfter["tok-to-remove"] == nil)
    }
}
