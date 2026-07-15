import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: PersonRepository {
    public func get(_ id: Identifier<Person>) async throws -> Person? {
        guard let row = try await peopleTable.fetchOne(id: id.rawValue) else { return nil }
        let goals = try await goalsTable.fetchAll { $0.eq("person_id", value: id.rawValue) }
        return row.toDomain(goals: goals.map(\.toDomain))
    }

    public func list() async throws -> [Person] {
        let rows = try await peopleTable.fetchAll()
        var people: [Person] = []
        people.reserveCapacity(rows.count)
        for row in rows {
            let goals = try await goalsTable.fetchAll { $0.eq("person_id", value: row.id.rawValue) }
            people.append(row.toDomain(goals: goals.map(\.toDomain)))
        }
        return people
    }

    public func upsert(_ person: Person) async throws -> Person {
        try await peopleTable.upsert(PersonRow(domain: person))
        try await goalsTable.deleteWhere(column: "person_id", value: person.id.rawValue)
        if !person.goals.isEmpty {
            let goalRows = person.goals.map { GoalRow(personID: person.id, domain: $0) }
            try await client.from("goals").insert(goalRows).execute()
        }
        return person
    }

    public func delete(_ id: Identifier<Person>) async throws {
        try await peopleTable.delete(id: id.rawValue)
    }

    // MARK: - Helpers

    var peopleTable: SupabaseTable<PersonRow> {
        SupabaseTable(client: client, queue: queue, table: "people")
    }

    var goalsTable: SupabaseTable<GoalRow> {
        SupabaseTable(client: client, queue: queue, table: "goals")
    }
}
