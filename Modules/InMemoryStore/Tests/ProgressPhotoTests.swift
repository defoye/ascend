import DataInterfaces
import Domain
import Foundation
import Testing
@testable import InMemoryStore

private struct StreamTestTimeoutError: Error {}

@Suite("ProgressPhotoRepository and photo consent")
struct ProgressPhotoTests {
    @Test("ProgressPhoto: upsert/fetch/delete round-trip")
    func progressPhotoCRUD() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let photo = ProgressPhoto(
            id: Identifier(),
            engagementID: engagementID,
            reference: "test-reference-1",
            capturedAt: Date(),
            source: .coachRecorded
        )

        _ = try await backend.progressPhotos.upsert(photo)
        let fetched = try await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)
        #expect(fetched == [photo])

        let byID = try await backend.progressPhotos.get(photo.id)
        #expect(byID == photo)

        try await backend.progressPhotos.delete(photo.id)
        let afterDelete = try await backend.progressPhotos.fetchPhotos(forEngagement: engagementID)
        #expect(afterDelete.isEmpty)
    }

    @Test("ProgressPhoto: delete of an unknown id throws")
    func progressPhotoDeleteUnknownThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.progressPhotos.delete(Identifier())
        }
    }

    @Test("photos(forEngagement:) emits an updated list after upsert")
    func photoStreamEmitsOnUpsert() async throws {
        let backend = InMemoryBackend()
        let engagementID = Identifier<Engagement>()
        let photo = ProgressPhoto(
            id: Identifier(),
            engagementID: engagementID,
            reference: "streamed-reference",
            capturedAt: Date(),
            source: .clientSelfReported
        )

        let received: [ProgressPhoto]? = try await withThrowingTaskGroup(of: [ProgressPhoto]?.self) { group in
            group.addTask {
                for await snapshot in backend.progressPhotos.photos(forEngagement: engagementID)
                    where snapshot.contains(where: { $0.id == photo.id }) {
                    return snapshot
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                throw StreamTestTimeoutError()
            }

            try await Task.sleep(nanoseconds: 100_000_000)
            _ = try await backend.progressPhotos.upsert(photo)

            guard let first = try await group.next() else { throw StreamTestTimeoutError() }
            group.cancelAll()
            return first
        }

        let photos = try #require(received)
        #expect(photos.map(\.id) == [photo.id])
    }

    @Test("photoConsent defaults false and is independent of outcome-derivation consent")
    func photoConsentIsSeparateFromOutcomeConsent() async throws {
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

        let defaultPhotoConsent = try await backend.engagements.photoConsent(for: engagement.id)
        #expect(defaultPhotoConsent == false)

        // Granting outcome-derivation consent must not implicitly grant photo consent.
        try await backend.engagements.setConsent(true, for: engagement.id)
        #expect(try await backend.engagements.photoConsent(for: engagement.id) == false)
        #expect(try await backend.engagements.consent(for: engagement.id) == true)

        try await backend.engagements.setPhotoConsent(true, for: engagement.id)
        #expect(try await backend.engagements.photoConsent(for: engagement.id) == true)
        // Outcome consent stays unaffected by the photo grant.
        #expect(try await backend.engagements.consent(for: engagement.id) == true)

        try await backend.engagements.setPhotoConsent(false, for: engagement.id)
        #expect(try await backend.engagements.photoConsent(for: engagement.id) == false)
    }

    @Test("photoConsent for an unknown engagement throws")
    func photoConsentUnknownEngagementThrows() async throws {
        let backend = InMemoryBackend()
        await #expect(throws: InMemoryStoreError.self) {
            try await backend.engagements.photoConsent(for: Identifier())
        }
    }

    @Test("seeded data grants photo consent to exactly one engagement, and seeds its photos")
    func seededPhotoConsentAndPhotos() async throws {
        let backend = InMemoryStore.seeded()
        let people = try await backend.people.list()
        let morgan = try #require(people.first { $0.displayName == "Morgan Chen" })
        let sam = try #require(people.first { $0.displayName == "Sam Patel" })
        let morganEngagement = try #require(try await backend.engagements.fetchEngagements(forClient: morgan.id).first)
        let samEngagement = try #require(try await backend.engagements.fetchEngagements(forClient: sam.id).first)

        #expect(try await backend.engagements.photoConsent(for: morganEngagement.id) == true)
        #expect(try await backend.engagements.photoConsent(for: samEngagement.id) == false)

        let morganPhotos = try await backend.progressPhotos.fetchPhotos(forEngagement: morganEngagement.id)
        #expect(morganPhotos.count == 2)
    }
}
