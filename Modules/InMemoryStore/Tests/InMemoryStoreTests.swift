import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

@Suite("InMemoryBackend CRUD")
struct InMemoryStoreTests {
    // MARK: - Person

    @Test("Person: upsert then get round-trips, delete removes it")
    func personCRUD() async throws {
        let backend = InMemoryBackend()
        let person = Person(id: Identifier(), displayName: "Test Person", roles: [.consumer], goals: [])

        let saved = try await backend.people.upsert(person)
        #expect(saved == person)

        let fetched = try await backend.people.get(person.id)
        #expect(fetched == person)

        let listed = try await backend.people.list()
        #expect(listed == [person])

        try await backend.people.delete(person.id)
        let afterDelete = try await backend.people.get(person.id)
        #expect(afterDelete == nil)
    }

    @Test("Person: delete of an unknown id throws")
    func personDeleteUnknownThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.people.delete(Identifier())
        }
    }

    // MARK: - ProfessionalRepository

    @Test("ProfessionalProfile: upsert, get, and lookup by professional person id")
    func professionalProfileCRUD() async throws {
        let backend = InMemoryBackend()
        let personID = Identifier<Person>()
        let profile = ProfessionalProfile(
            id: Identifier(),
            personID: personID,
            displayName: "Coach Test",
            headline: "Headline",
            bio: "Bio",
            services: [],
            verifications: []
        )

        _ = try await backend.professionals.upsert(profile)

        let byID = try await backend.professionals.get(profile.id)
        #expect(byID == profile)

        let byPerson = try await backend.professionals.profile(forProfessional: personID)
        #expect(byPerson == profile)
    }

    // MARK: - Engagement + consent

    @Test("Engagement: upsert/get/delete round-trip, consent defaults false then can be set")
    func engagementCRUDAndConsent() async throws {
        let backend = InMemoryBackend()
        let engagement = Engagement(
            id: Identifier(),
            clientID: Identifier(),
            professionalID: Identifier(),
            status: .active,
            startedAt: Date(),
            endedAt: nil
        )
        _ = try await backend.engagements.upsert(engagement)

        let fetched = try await backend.engagements.get(engagement.id)
        #expect(fetched == engagement)

        let defaultConsent = try await backend.engagements.consent(for: engagement.id)
        #expect(defaultConsent == false)

        try await backend.engagements.setConsent(true, for: engagement.id)
        let grantedConsent = try await backend.engagements.consent(for: engagement.id)
        #expect(grantedConsent == true)

        let forProfessional = try await backend.engagements.fetchEngagements(forProfessional: engagement.professionalID)
        #expect(forProfessional == [engagement])

        try await backend.engagements.delete(engagement.id)
        let afterDelete = try await backend.engagements.get(engagement.id)
        #expect(afterDelete == nil)
    }

    // MARK: - Session

    @Test("Session: upsert/get/fetch/delete round-trip")
    func sessionCRUD() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let session = Session(id: Identifier(), engagementID: engagementID, scheduledAt: Date(), status: .scheduled)

        _ = try await backend.sessions.upsert(session)
        let fetched = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        #expect(fetched == [session])

        try await backend.sessions.delete(session.id)
        let afterDelete = try await backend.sessions.fetchSessions(forEngagement: engagementID)
        #expect(afterDelete.isEmpty)
    }

    // MARK: - ProgressEntry

    @Test("ProgressEntry: upsert/fetch by engagement and by metric")
    func progressCRUD() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let bodyweight = ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: .bodyweight,
            value: MetricValue(value: 180, unit: .lb),
            recordedAt: Date(),
            source: .coachRecorded
        )
        let squat = ProgressEntry(
            id: Identifier(),
            engagementID: engagementID,
            metric: .squat1RM,
            value: MetricValue(value: 200, unit: .lb),
            recordedAt: Date(),
            source: .coachRecorded
        )
        _ = try await backend.progress.upsert(bodyweight)
        _ = try await backend.progress.upsert(squat)

        let all = try await backend.progress.fetchEntries(forEngagement: engagementID)
        #expect(Set(all.map(\.id)) == Set([bodyweight.id, squat.id]))

        let bodyweightOnly = try await backend.progress.fetchEntries(forEngagement: engagementID, metric: .bodyweight)
        #expect(bodyweightOnly == [bodyweight])
    }

    // MARK: - Payment

    @Test("Payment: upsert/fetch/delete round-trip")
    func paymentCRUD() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let payment = Payment(
            id: Identifier(),
            engagementID: engagementID,
            amountCents: 10_000,
            currency: "USD",
            status: .succeeded,
            platformFeeCents: 1_000,
            stripePaymentIntentID: "pi_test",
            createdAt: Date()
        )
        _ = try await backend.payments.upsert(payment)

        let fetched = try await backend.payments.payments(forEngagement: engagementID)
        #expect(fetched == [payment])

        try await backend.payments.delete(payment.id)
        let afterDelete = try await backend.payments.payments(forEngagement: engagementID)
        #expect(afterDelete.isEmpty)
    }

    // MARK: - Program + assignment

    @Test("Program: upsert/list by author, assign to an engagement")
    func programCRUDAndAssignment() async throws {
        let backend = InMemoryBackend()
        let authorID = Identifier<Person>()
        let program = Program(id: Identifier(), authorID: authorID, title: "Test Program", summary: "Summary", weeks: [])
        _ = try await backend.programs.upsert(program)

        let listed = try await backend.programs.list(forAuthor: authorID)
        #expect(listed == [program])

        let engagementID = Identifier<Engagement>()
        let assignment = ProgramAssignment(
            id: Identifier(),
            programID: program.id,
            engagementID: engagementID,
            assignedAt: Date(),
            startDate: Date()
        )
        _ = try await backend.programs.assign(assignment)

        let assignments = try await backend.programs.assignments(forEngagement: engagementID)
        #expect(assignments == [assignment])
    }

    // MARK: - AvailabilityWindow

    @Test("AvailabilityWindow: upsert/fetch/delete round-trip")
    func availabilityCRUD() async throws {
        let backend = InMemoryBackend()
        let professionalID = Identifier<Person>()
        let window = AvailabilityWindow(id: Identifier(), professionalID: professionalID, weekday: 2, startMinute: 540, endMinute: 1_020)

        _ = try await backend.availability.upsert(window)
        let fetched = try await backend.availability.windows(forProfessional: professionalID)
        #expect(fetched == [window])

        try await backend.availability.delete(window.id)
        let afterDelete = try await backend.availability.windows(forProfessional: professionalID)
        #expect(afterDelete.isEmpty)
    }

    @Test("AvailabilityWindow: delete of an unknown id throws")
    func availabilityDeleteUnknownThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.availability.delete(Identifier())
        }
    }

    // MARK: - Auth

    @Test("AuthGateway: sign up, sign in, sign out transitions currentAuthState")
    func authFlow() async throws {
        let backend = InMemoryBackend()
        let outcome = try await backend.signUp(email: "new@example.com", password: "secret", displayName: "New User", roles: [.consumer])
        #expect(outcome == .signedIn)
        try await backend.signOut()

        await #expect(throws: InMemoryStoreError.self) {
            try await backend.signIn(email: "new@example.com", password: "wrong-password")
        }

        try await backend.signIn(email: "new@example.com", password: "secret")
    }

    @Test("AuthGateway: signUp(roles:) sets exactly the coach-only roles on the created Person")
    func signUpCoachOnlySetsRoles() async throws {
        let backend = InMemoryBackend()
        try await backend.signUp(email: "coach@example.com", password: "secret", displayName: "Coach Only", roles: [.professional])

        guard case let .signedIn(user) = await backend.currentAuthState else {
            Issue.record("Expected signed-in state after sign-up")
            return
        }
        let person = try await backend.people.get(user.personID)
        #expect(person?.roles == [.professional])
    }

    @Test("AuthGateway: signUp(roles:) sets exactly the client-only roles on the created Person")
    func signUpClientOnlySetsRoles() async throws {
        let backend = InMemoryBackend()
        try await backend.signUp(email: "client@example.com", password: "secret", displayName: "Client Only", roles: [.consumer])

        guard case let .signedIn(user) = await backend.currentAuthState else {
            Issue.record("Expected signed-in state after sign-up")
            return
        }
        let person = try await backend.people.get(user.personID)
        #expect(person?.roles == [.consumer])
    }

    @Test("AuthGateway: signUp(roles:) sets both roles when both are chosen")
    func signUpBothSetsRoles() async throws {
        let backend = InMemoryBackend()
        try await backend.signUp(
            email: "both@example.com",
            password: "secret",
            displayName: "Both Roles",
            roles: [.professional, .consumer]
        )

        guard case let .signedIn(user) = await backend.currentAuthState else {
            Issue.record("Expected signed-in state after sign-up")
            return
        }
        let person = try await backend.people.get(user.personID)
        #expect(person?.roles == [.professional, .consumer])
    }

    @Test("AuthGateway: signUp with an empty roles set is rejected")
    func signUpEmptyRolesRejected() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: AuthGatewayError.rolesRequired) {
            try await backend.signUp(email: "norole@example.com", password: "secret", displayName: "No Role", roles: [])
        }
    }

    @Test("AuthGateway: deleteAccount removes the signed-in user from registeredUsers and signs out")
    func deleteAccountRemovesUserAndSignsOut() async throws {
        let backend = InMemoryBackend()
        try await backend.signUp(email: "gone@example.com", password: "secret", displayName: "Gone Soon", roles: [.consumer])

        try await backend.deleteAccount()

        let stateAfter = await backend.currentAuthState
        #expect(stateAfter == .signedOut)
        let registeredAfter = await backend.registeredUsers
        #expect(registeredAfter["gone@example.com"] == nil)

        await #expect(throws: InMemoryStoreError.self) {
            try await backend.signIn(email: "gone@example.com", password: "secret")
        }
    }
}
