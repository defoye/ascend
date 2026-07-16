import Domain

/// A `DeviceTokenRepository` that does nothing — the default `Backend.deviceTokens`
/// vends this (see `Backend.swift`'s extension), mirroring `NoOpPaymentGateway`'s
/// role as a safe stand-in so every conformer gets a real, total value without
/// having to implement this repository itself.
public struct NoOpDeviceTokenRepository: DeviceTokenRepository, Sendable {
    public init() {}

    public func register(token: String, platform: String) async throws {}

    public func unregister(token: String) async throws {}
}
