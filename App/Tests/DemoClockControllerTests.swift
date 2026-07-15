import Foundation
import Testing

@testable import Ascend

@Suite("DemoClockController / DemoClockBox")
@MainActor
struct DemoClockControllerTests {
    @Test("the clock closure reflects the controller's currentDate synchronously")
    func clockClosureReflectsCurrentDate() {
        let initial = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = DemoClockController(initialDate: initial)
        #expect(controller.clock() == initial)

        let updated = Date(timeIntervalSince1970: 1_800_000_000)
        controller.currentDate = updated
        #expect(controller.clock() == updated)
    }

    @Test("DemoClockBox reads back exactly what was last set")
    func boxReadsBackLastSet() {
        let box = DemoClockBox(date: Date(timeIntervalSince1970: 0))
        let newDate = Date(timeIntervalSince1970: 42)
        box.set(newDate)
        #expect(box.current == newDate)
    }
}
