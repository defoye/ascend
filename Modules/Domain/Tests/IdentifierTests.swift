import Foundation
import Testing
@testable import Domain

@Suite("Identifier")
struct IdentifierTests {
    @Test("Encodes as a bare quoted UUID string, not a nested object")
    func encodesAsBareString() throws {
        let uuid = UUID()
        let identifier = Identifier<Person>(uuid)

        let data = try JSONEncoder().encode(identifier)
        let json = String(decoding: data, as: UTF8.self)

        // No object braces — this is a bare JSON string, not `{"uuid":"..."}`.
        #expect(!json.contains("{"))
        #expect(!json.contains("}"))

        let decodedString = try JSONDecoder().decode(String.self, from: data)
        #expect(decodedString == uuid.uuidString)
    }

    @Test("Decodes back to an equal Identifier")
    func roundTrips() throws {
        let uuid = UUID()
        let identifier = Identifier<Person>(uuid)

        let data = try JSONEncoder().encode(identifier)
        let decoded = try JSONDecoder().decode(Identifier<Person>.self, from: data)

        #expect(decoded == identifier)
        #expect(decoded.uuid == uuid)
        #expect(decoded.rawValue == uuid.uuidString)
    }

    @Test("Throws a decoding error for an invalid UUID string, never force-unwraps")
    func rejectsInvalidUUIDString() throws {
        let data = Data("\"not-a-uuid\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Identifier<Person>.self, from: data)
        }
    }

    /// A struct that contains an `Identifier` field, used to prove the identifier
    /// serializes as a bare string even when nested inside another Codable type.
    private struct Wrapper: Codable {
        let personID: Identifier<Person>
        let label: String
    }

    @Test("A field of type Identifier serializes as a bare string, not a nested object")
    func nestedFieldSerializesAsBareString() throws {
        let uuid = UUID()
        let wrapper = Wrapper(personID: Identifier(uuid), label: "coach")

        let data = try JSONEncoder().encode(wrapper)
        let decodedObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let personIDValue = try #require(decodedObject?["personID"])
        #expect(personIDValue is String)
        #expect((personIDValue as? String) == uuid.uuidString)

        let decodedWrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        #expect(decodedWrapper.personID == Identifier(uuid))
        #expect(decodedWrapper.label == "coach")
    }
}
