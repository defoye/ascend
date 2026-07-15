import Domain
import Foundation
import InMemoryStore
import Testing
@testable import Features

@Suite("RoleActivitySummary")
struct RoleActivitySummaryTests {
    // MARK: - hasUpdates (pure comparison)

    @Test("no inbound activity never shows a dot")
    func noActivityMeansNoUpdates() {
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: nil, sinceLastVisited: nil) == false)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: nil, sinceLastVisited: Date()) == false)
    }

    @Test("inbound activity with no recorded visit shows a dot")
    func activityWithNoVisitMeansUpdates() {
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: Date(), sinceLastVisited: nil) == true)
    }

    @Test("inbound activity newer than the last visit shows a dot")
    func newerActivityMeansUpdates() {
        let lastVisited = Date(timeIntervalSince1970: 1_000)
        let newerActivity = lastVisited.addingTimeInterval(60)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: newerActivity, sinceLastVisited: lastVisited) == true)
    }

    @Test("inbound activity at or before the last visit shows no dot")
    func staleActivityMeansNoUpdates() {
        let lastVisited = Date(timeIntervalSince1970: 1_000)
        let staleActivity = lastVisited.addingTimeInterval(-60)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: staleActivity, sinceLastVisited: lastVisited) == false)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: lastVisited, sinceLastVisited: lastVisited) == false)
    }

    // MARK: - professionalInboundActivity / consumerInboundActivity against seeded data

    @Test("professionalInboundActivity finds seeded client-authored activity")
    func professionalInboundActivityFindsSeededActivity() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.displayName == "Jordan Ellis" })

        let latest = await RoleActivitySummary.professionalInboundActivity(backend: backend, professionalID: professional.id)
        #expect(latest != nil)
    }

    @Test("consumerInboundActivity finds seeded coach-authored activity for the demo client")
    func consumerInboundActivityFindsSeededActivity() async throws {
        let backend = InMemoryStore.seeded()

        let latest = await RoleActivitySummary.consumerInboundActivity(backend: backend, clientID: InMemoryStore.demoClientPersonID)
        #expect(latest != nil)
    }

    @Test("a new client message pushes professionalInboundActivity forward, and the dot follows last-visited")
    func newClientMessageDrivesTheDot() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagements = try await backend.engagements.fetchEngagements(forProfessional: professional.id)
        let engagement = try #require(engagements.first)

        let beforeSend = Date()
        let farFuture = beforeSend.addingTimeInterval(1_000)
        try await backend.messages.send(
            Message(id: Identifier(), engagementID: engagement.id, authorID: engagement.clientID, body: "New PR today!", sentAt: farFuture)
        )

        let latest = await RoleActivitySummary.professionalInboundActivity(backend: backend, professionalID: professional.id)
        #expect(latest == farFuture)

        // (a) newer inbound activity than the last visit -> dot on.
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: latest, sinceLastVisited: beforeSend) == true)

        // (b) after "visiting" (last-visited advanced past the new activity) -> dot off.
        let afterSend = farFuture.addingTimeInterval(1)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: latest, sinceLastVisited: afterSend) == false)
    }

    @Test("a new coach message pushes consumerInboundActivity forward")
    func newCoachMessageDrivesTheDot() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let professional = try #require(people.first { $0.displayName == "Jordan Ellis" })
        let engagements = try await backend.engagements.fetchEngagements(forClient: InMemoryStore.demoClientPersonID)
        let engagement = try #require(engagements.first)

        let beforeSend = Date()
        let farFuture = beforeSend.addingTimeInterval(1_000)
        try await backend.messages.send(
            Message(id: Identifier(), engagementID: engagement.id, authorID: professional.id, body: "Great work this week!", sentAt: farFuture)
        )

        let latest = await RoleActivitySummary.consumerInboundActivity(backend: backend, clientID: InMemoryStore.demoClientPersonID)
        #expect(latest == farFuture)
        #expect(RoleActivitySummary.hasUpdates(latestInboundActivity: latest, sinceLastVisited: beforeSend) == true)
    }
}
