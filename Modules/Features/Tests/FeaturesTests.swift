import Testing
@testable import Features

@Suite("Features placeholder")
struct FeaturesTests {
    @Test("Module links")
    func placeholder() {
        // Placeholder test until later prompts add Features screens and view models.
        let name = String(describing: Features.self)
        #expect(name == "Features")
    }
}
