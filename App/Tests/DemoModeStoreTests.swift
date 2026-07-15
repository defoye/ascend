import Foundation
import Testing

@testable import Ascend

@Suite("DemoModeStore persistence")
@MainActor
struct DemoModeStoreTests {
    @Test("defaults to disabled and richDemo when nothing persisted")
    func defaultsAreOffAndRichDemo() throws {
        let defaults = try #require(UserDefaults(suiteName: "DemoModeStoreTests.\(UUID().uuidString)"))
        let store = DemoModeStore(defaults: defaults)
        #expect(store.isEnabled == false)
        #expect(store.scenario == .richDemo)
    }

    @Test("isEnabled and scenario persist across store instances sharing the same UserDefaults")
    func persistsAcrossInstances() throws {
        let defaults = try #require(UserDefaults(suiteName: "DemoModeStoreTests.\(UUID().uuidString)"))
        let store = DemoModeStore(defaults: defaults)
        store.isEnabled = true
        store.scenario = .showcase

        let reloaded = DemoModeStore(defaults: defaults)
        #expect(reloaded.isEnabled == true)
        #expect(reloaded.scenario == .showcase)
    }

    @Test("flipping isEnabled back off persists as off")
    func flippingOffPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: "DemoModeStoreTests.\(UUID().uuidString)"))
        let store = DemoModeStore(defaults: defaults)
        store.isEnabled = true
        store.isEnabled = false

        let reloaded = DemoModeStore(defaults: defaults)
        #expect(reloaded.isEnabled == false)
    }
}
