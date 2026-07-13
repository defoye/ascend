import Domain

/// The currently signed-in user's identity, as known to auth — independent of,
/// but linked to, their `Person` record via `personID`.
public struct AuthenticatedUser: Sendable, Hashable, Codable {
    public let personID: Identifier<Person>
    public let displayName: String
    public let email: String

    public init(personID: Identifier<Person>, displayName: String, email: String) {
        self.personID = personID
        self.displayName = displayName
        self.email = email
    }
}
