import Testing
@testable import InMemoryStore

@Suite("InMemoryStore placeholder")
struct InMemoryStoreTests {
    @Test("Module links")
    func placeholder() {
        // Placeholder test until Prompt 3 implements the InMemoryStore adapter
        // and MockData / seeded() (see docs/BACKEND.md, docs/TESTING.md).
        let name = String(describing: InMemoryStore.self)
        #expect(name == "InMemoryStore")
    }
}
