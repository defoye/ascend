import Foundation

/// A phantom-typed wrapper around `UUID` used as the identifier for a specific
/// entity type `Entity`.
///
/// Deliberately **not** named `ID`, because that would collide with
/// `Identifiable.ID` on conforming types. `Entity` is a pure phantom type — it is
/// never stored — used only to prevent mixing identifiers across entity kinds at
/// compile time (e.g. an `Identifier<Person>` cannot be passed where an
/// `Identifier<Engagement>` is expected).
///
/// Encodes/decodes as a bare JSON string (the UUID's string representation),
/// not as a nested object.
public struct Identifier<Entity>: Hashable, Sendable, Codable, CustomStringConvertible {
    public let uuid: UUID

    public init(_ uuid: UUID = UUID()) {
        self.uuid = uuid
    }

    public var rawValue: String {
        uuid.uuidString
    }

    public var description: String {
        rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard let decodedUUID = UUID(uuidString: stringValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid UUID string: \(stringValue)"
                )
            )
        }
        self.uuid = decodedUUID
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uuid.uuidString)
    }
}
