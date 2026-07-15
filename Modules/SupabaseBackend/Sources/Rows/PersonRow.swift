import Domain
import Foundation

/// Row for the `people` table. `Person.goals` lives in the separate `goals`
/// table (see `GoalRow`) and is joined in by `SupabaseBackend+PersonRepository`.
struct PersonRow: SupabaseRow {
    let id: Identifier<Person>
    let displayName: String
    let roles: Set<PersonRole>

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case roles
    }

    init(id: Identifier<Person>, displayName: String, roles: Set<PersonRole>) {
        self.id = id
        self.displayName = displayName
        self.roles = roles
    }

    init(domain: Person) {
        id = domain.id
        displayName = domain.displayName
        roles = domain.roles
    }

    func toDomain(goals: [Goal]) -> Person {
        Person(id: id, displayName: displayName, roles: roles, goals: goals)
    }
}

/// Row for the `goals` table, joined into `Person.goals` by `personID`.
struct GoalRow: SupabaseRow {
    let id: Identifier<Goal>
    let personID: Identifier<Person>
    let kind: GoalKind
    let metric: MetricKind?
    let targetValue: Double?
    let targetUnit: MetricUnit?
    let deadline: Date?

    var rowID: String { id.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case personID = "person_id"
        case kind
        case metric
        case targetValue = "target_value"
        case targetUnit = "target_unit"
        case deadline
    }

    init(personID: Identifier<Person>, domain: Goal) {
        id = domain.id
        self.personID = personID
        kind = domain.kind
        metric = domain.metric
        targetValue = domain.target?.value
        targetUnit = domain.target?.unit
        deadline = domain.deadline
    }

    var toDomain: Goal {
        let target: MetricValue? = targetValue.flatMap { value in
            targetUnit.map { MetricValue(value: value, unit: $0) }
        }
        return Goal(id: id, kind: kind, metric: metric, target: target, deadline: deadline)
    }
}
