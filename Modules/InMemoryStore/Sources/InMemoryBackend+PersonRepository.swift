import DataInterfaces
import Domain

extension InMemoryBackend: PersonRepository {
    public func get(_ id: Identifier<Person>) async throws -> Person? {
        peopleByID[id]
    }

    public func list() async throws -> [Person] {
        Array(peopleByID.values).sorted { $0.displayName < $1.displayName }
    }

    public func upsert(_ person: Person) async throws -> Person {
        peopleByID[person.id] = person
        return person
    }

    public func delete(_ id: Identifier<Person>) async throws {
        guard peopleByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }
}
