#if DEBUG

import DataInterfaces
import Foundation
import InMemoryStore
import Observation

/// Owns the demo harness's live-swappable state: the currently active
/// scenario's backend bundle, the demo clock, and the payment-outcome
/// controller. A single instance lives on `RootView` (see `AscendApp.swift`)
/// and is threaded into both the control panel (to edit it) and the
/// coach/consumer roots (to render against it).
@MainActor
@Observable
final class DemoHarnessState {
    private(set) var bundle: DemoBackendBundle?
    private(set) var isLoading = false
    let clockController: DemoClockController
    let paymentController = DemoPaymentOutcomeController()

    init(referenceDate: Date = InMemoryStore.referenceDate) {
        clockController = DemoClockController(initialDate: referenceDate)
    }

    /// Rebuilds `bundle` for `scenario`, wrapping the scenario's raw backend
    /// in `DemoBackend` so the payment-outcome control applies to it.
    func load(scenario: DemoScenario) async {
        isLoading = true
        let rawBundle = await DemoScenarioFactory.makeBundle(for: scenario)
        let backend = DemoBackend(wrapped: rawBundle.backend, paymentOutcomeController: paymentController)
        bundle = DemoBackendBundle(backend: backend, professionalID: rawBundle.professionalID, clientID: rawBundle.clientID)
        isLoading = false
    }
}

#endif
