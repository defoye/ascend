import Domain

/// Registration of this device's APNs token for the signed-in person, so the
/// server can push message notifications to it. Each adapter derives WHICH
/// person from its own current auth session — callers never pass a personID.
public protocol DeviceTokenRepository: Sendable {
    func register(token: String, platform: String) async throws
    func unregister(token: String) async throws
}
