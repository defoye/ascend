import XCTest

/// Drives the real tap path for the DEBUG-only demo harness (see
/// docs/TESTABILITY.md) inside the simulator via Xcode's UI-testing
/// infrastructure — the deterministic equivalent of a human tapping the
/// wrench button, flipping the toggle, and relaunching to check it stuck.
final class DemoHarnessUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The full hard-requirement loop: demo mode starts off, the wrench
    /// button is discoverable and opens the control panel, the toggle
    /// flips it on, and that state survives an app relaunch — then flips
    /// back off so the device is left in its default state.
    func testDemoModeToggleTapPathAndPersistence() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-com.ascend.demo.isEnabled", "NO"]
        app.launch()

        let launcher = app.buttons["demoLauncherButton"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 10), "The demo launcher button must be discoverable on a normal launch")
        launcher.tap()

        let title = app.navigationBars["Demo Mode"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Tapping the launcher must open the Demo Mode control panel")

        let toggle = app.switches["demoModeToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0", "Demo mode must default to off")

        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1", "Tapping the toggle must flip demo mode on")

        let showcaseRow = app.buttons["scenario_showcase"]
        XCTAssertTrue(showcaseRow.waitForExistence(timeout: 5), "Enabling demo mode must reveal the scenario switcher")

        app.terminate()

        // Relaunch with no override — the persisted UserDefaults value from
        // the toggle above should still be on.
        let relaunched = XCUIApplication()
        relaunched.launch()

        let relaunchedLauncher = relaunched.buttons["demoLauncherButton"]
        XCTAssertTrue(relaunchedLauncher.waitForExistence(timeout: 10))
        relaunchedLauncher.tap()

        let relaunchedToggle = relaunched.switches["demoModeToggle"]
        XCTAssertTrue(relaunchedToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(relaunchedToggle.value as? String, "1", "Demo mode must persist across a relaunch")

        // Leave the app in its default (off) state for subsequent runs.
        relaunchedToggle.tap()
        XCTAssertEqual(relaunchedToggle.value as? String, "0")
    }
}
