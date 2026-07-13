import Testing
@testable import DesignSystem

@Suite("DesignSystem placeholder")
struct DesignSystemTests {
    @Test("Module links")
    func placeholder() {
        // Placeholder test until later prompts add DesignSystem components.
        let name = String(describing: DesignSystem.self)
        #expect(name == "DesignSystem")
    }
}
