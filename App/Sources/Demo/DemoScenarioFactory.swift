#if DEBUG

import DataInterfaces
import Domain
import Foundation
import InMemoryStore

/// A fully-wired demo backend plus the identifiers the harness needs to
/// jump straight into the coach/consumer experience against it — built once
/// per scenario switch (see `DemoScenario`).
struct DemoBackendBundle {
    let backend: any Backend
    let professionalID: Identifier<Person>
    let clientID: Identifier<Person>
}

/// Builds a `DemoBackendBundle` for each `DemoScenario`, using only
/// `Backend` protocol calls (never `InMemoryBackend` internals beyond
/// constructing one) so this stays a legitimate, adapter-swap-safe
/// composition, exactly like the rest of the App composition root (see
/// docs/ARCHITECTURE.md).
enum DemoScenarioFactory {
    static func makeBundle(for scenario: DemoScenario) async -> DemoBackendBundle {
        switch scenario {
        case .richDemo:
            return await makeRichDemo()
        case .showcase:
            return await makeShowcase()
        case .emptyCoach:
            return await makeEmptyCoach()
        case .errorStates:
            return await makeErrorStates()
        }
    }

    private static func makeRichDemo() async -> DemoBackendBundle {
        let backend = InMemoryStore.seeded()
        let professionalID = await signedInPersonID(backend) ?? Identifier<Person>()
        return DemoBackendBundle(backend: backend, professionalID: professionalID, clientID: InMemoryStore.demoClientPersonID)
    }

    /// Rich demo data plus one guaranteed refund, so every important state
    /// exists at once (see docs/TESTABILITY.md's "showcase" fixture): a
    /// verified outcome, consent on and off, an empty (`.pending`, no
    /// activity) client, upcoming and past sessions, and unread messages
    /// all already exist in the base seeded fixture (see
    /// `MockData+Activity.swift`/`MockData+Engagements.swift`) — the only
    /// gap is a `.refunded` payment, added here via the real
    /// `PaymentGateway.refund`, never a hand-authored `Payment`.
    private static func makeShowcase() async -> DemoBackendBundle {
        let backend = InMemoryStore.seeded()
        let professionalID = await signedInPersonID(backend) ?? Identifier<Person>()
        await refundFirstSucceededPayment(backend: backend, professionalID: professionalID)
        return DemoBackendBundle(backend: backend, professionalID: professionalID, clientID: InMemoryStore.demoClientPersonID)
    }

    private static func refundFirstSucceededPayment(backend: any Backend, professionalID: Identifier<Person>) async {
        guard let engagements = try? await backend.engagements.fetchEngagements(forProfessional: professionalID) else { return }
        for engagement in engagements {
            guard let payments = try? await backend.payments.payments(forEngagement: engagement.id) else { continue }
            guard let succeeded = payments.first(where: { $0.status == .succeeded }) else { continue }
            _ = try? await backend.paymentGateway.refund(paymentID: succeeded.id)
            return
        }
    }

    /// A freshly signed-up coach with zero clients/programs/sessions —
    /// every screen's empty state, reached the same way a real new coach
    /// would hit it (`AuthGateway.signUp`, then `PersonRepository.upsert`/
    /// `ProfessionalRepository.upsert` — never by hand-poking storage).
    private static func makeEmptyCoach() async -> DemoBackendBundle {
        let backend = InMemoryBackend()
        let email = "demo-empty-\(UUID().uuidString.prefix(8))@ascend.coach"
        try? await backend.auth.signUp(email: email, password: "password123", displayName: "New Coach")
        guard let personID = await signedInPersonID(backend) else {
            return DemoBackendBundle(backend: backend, professionalID: Identifier<Person>(), clientID: Identifier<Person>())
        }
        _ = try? await backend.people.upsert(Person(id: personID, displayName: "New Coach", roles: [.professional], goals: []))
        let profile = ProfessionalProfile(
            id: Identifier(),
            personID: personID,
            displayName: "New Coach",
            headline: "Just getting started",
            bio: "",
            services: [],
            verifications: []
        )
        _ = try? await backend.professionals.upsert(profile)
        return DemoBackendBundle(backend: backend, professionalID: personID, clientID: Identifier<Person>())
    }

    private static func makeErrorStates() async -> DemoBackendBundle {
        let rich = await makeRichDemo()
        return DemoBackendBundle(
            backend: DemoErrorInjectingBackend(wrapped: rich.backend),
            professionalID: rich.professionalID,
            clientID: rich.clientID
        )
    }

    /// The signed-in person's id from the backend's live auth state — the
    /// first emission, since `AuthGateway.currentAuth` "emits the current
    /// state immediately upon subscription" (see `AuthGateway`).
    private static func signedInPersonID(_ backend: any Backend) async -> Identifier<Person>? {
        for await state in backend.auth.currentAuth {
            if case let .signedIn(user) = state { return user.personID }
            return nil
        }
        return nil
    }
}

#endif
