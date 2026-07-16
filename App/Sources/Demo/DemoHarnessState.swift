#if DEBUG

import DataInterfaces
import Foundation
import InMemoryStore
import Observation

/// Owns the demo harness's live-swappable state: the currently active
/// scenario's backend bundle and the demo clock. A single instance lives on
/// `RootView` (see `AscendApp.swift`) and is threaded into both the control
/// panel (to edit it) and the coach/consumer roots (to render against it).
@MainActor
@Observable
final class DemoHarnessState {
    private(set) var bundle: DemoBackendBundle?
    private(set) var isLoading = false
    let clockController: DemoClockController

    init(referenceDate: Date = InMemoryStore.referenceDate) {
        clockController = DemoClockController(initialDate: referenceDate)
    }

    /// Rebuilds `bundle` for `scenario`.
    func load(scenario: DemoScenario) async {
        isLoading = true
        bundle = await DemoScenarioFactory.makeBundle(for: scenario)
        isLoading = false
    }
}

#endif
