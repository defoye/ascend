#if DEBUG

import Foundation
import Observation

/// The demo/testability harness's persisted on/off switch (see
/// docs/TESTABILITY.md). `isEnabled` defaults to `false` — a normal DEBUG
/// launch is the ordinary seeded app — and is flippable from the in-app
/// wrench button (`DemoLauncherButton`). Both `isEnabled` and the selected
/// `scenario` are written to `UserDefaults` on every change, so flipping
/// demo mode on stays on across a relaunch until flipped off again.
@MainActor
@Observable
final class DemoModeStore {
    private static let isEnabledKey = "com.ascend.demo.isEnabled"
    private static let scenarioKey = "com.ascend.demo.scenario"

    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.isEnabledKey) }
    }

    var scenario: DemoScenario {
        didSet { defaults.set(scenario.rawValue, forKey: Self.scenarioKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.isEnabledKey)
        scenario = DemoScenario(rawValue: defaults.string(forKey: Self.scenarioKey) ?? "") ?? .richDemo
    }
}

#endif
