import DataInterfaces
import Domain

extension InMemoryBackend: DeviceTokenRepository {
    public func register(token: String, platform: String) async throws {
        guard case let .signedIn(user) = currentAuthState else { return }
        deviceTokensByToken[token] = (user.personID, platform)
    }

    public func unregister(token: String) async throws {
        deviceTokensByToken.removeValue(forKey: token)
    }

    /// Test-only accessor: which person each currently registered token
    /// belongs to, dropping the platform detail tests don't need to assert.
    public func registeredDeviceTokens() -> [String: Identifier<Person>] {
        deviceTokensByToken.mapValues(\.personID)
    }
}
