import Observation

/// Holds this device's current APNs token, bridged in from the App target's
/// `UIApplicationDelegate` (which owns the only code path that can obtain
/// one — see `App/Sources/AppDelegate.swift`). Foundation/Observation only,
/// no UIKit: `Features` never depends on a concrete push-registration API,
/// only on this seam.
@MainActor
@Observable
public final class DeviceTokenStore {
    public var token: String?

    public init() {}
}
