import Domain

/// CRUD access to `Person` records.
public protocol PersonRepository: Sendable {
    func get(_ id: Identifier<Person>) async throws -> Person?
    func list() async throws -> [Person]
    func upsert(_ person: Person) async throws -> Person
    func delete(_ id: Identifier<Person>) async throws
}
