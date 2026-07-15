import Domain
import Foundation

extension MockData {
    // MARK: - Identifiers

    static let professionalPersonID = Identifier<Person>(uuid(1, 0))
    static let professionalProfileID = Identifier<ProfessionalProfile>(uuid(3, 0))

    /// The eight clients, in fixture order — see `MockData+Engagements.swift` for
    /// how each maps to an `EngagementStatus` and outcome eligibility.
    static let clientNames = [
        "Alex Rivera",
        "Morgan Chen",
        "Sam Patel",
        "Taylor Brooks",
        "Jamie Nguyen",
        "Casey Whitfield",
        "Riley Thompson",
        "Drew Bennett"
    ]

    static func clientPersonID(_ index: Int) -> Identifier<Person> {
        Identifier(uuid(2, UInt8(index)))
    }

    // MARK: - People

    static func allPeople() -> [Person] {
        [professionalPerson()] + clientPeople()
    }

    /// Holds **both** roles (see docs/PRODUCT.md — "One `Person`, with role
    /// modes consumer / professional / both") so the roles-gated switcher
    /// (`RoleGating.switcherAvailable`) is actually exercised for the seeded
    /// demo person, keeping the existing demo "Switch role" flow reachable.
    static func professionalPerson() -> Person {
        Person(
            id: professionalPersonID,
            displayName: "Jordan Ellis",
            roles: [.professional, .consumer],
            goals: []
        )
    }

    static func clientPeople() -> [Person] {
        clientNames.indices.map { index in
            Person(
                id: clientPersonID(index),
                displayName: clientNames[index],
                roles: [.consumer],
                goals: [clientGoal(index)]
            )
        }
    }

    static func clientGoal(_ index: Int) -> Goal {
        let kinds: [GoalKind] = [
            .loseWeight, .buildMuscle, .getStronger, .loseWeight,
            .improveEndurance, .loseWeight, .getStronger, .getStronger
        ]
        return Goal(
            id: Identifier(uuid(17, UInt8(index))),
            kind: kinds[index],
            metric: nil,
            target: nil,
            deadline: nil
        )
    }

    // MARK: - Professional profile

    static func professionalProfile() -> ProfessionalProfile {
        ProfessionalProfile(
            id: professionalProfileID,
            personID: professionalPersonID,
            displayName: "Jordan Ellis",
            headline: "Certified strength & weight-loss coach",
            bio: """
            10 years coaching strength training and sustainable weight loss. \
            I build programs around your schedule and your numbers — every \
            client's progress is tracked and verified, not just promised.
            """,
            services: professionalServices(),
            verifications: professionalVerifications()
        )
    }

    static func professionalServices() -> [Service] {
        [
            Service(
                id: Identifier(uuid(4, 0)),
                category: .strengthTraining,
                title: "1:1 Strength Coaching",
                priceCents: 15_000,
                currency: "USD",
                modality: .hybrid
            ),
            Service(
                id: Identifier(uuid(4, 1)),
                category: .weightLoss,
                title: "Weight Loss Program",
                priceCents: 12_000,
                currency: "USD",
                modality: .virtual
            ),
            Service(
                id: Identifier(uuid(4, 2)),
                category: .mobility,
                title: "Mobility Session",
                priceCents: 8_000,
                currency: "USD",
                modality: .inPerson
            )
        ]
    }

    static func professionalVerifications() -> [Verification] {
        [
            Verification(id: Identifier(uuid(5, 0)), kind: .identity, status: .verified, evidenceURL: nil),
            Verification(id: Identifier(uuid(5, 1)), kind: .certification, status: .verified, evidenceURL: nil),
            Verification(id: Identifier(uuid(5, 2)), kind: .insurance, status: .pending, evidenceURL: nil)
        ]
    }
}
