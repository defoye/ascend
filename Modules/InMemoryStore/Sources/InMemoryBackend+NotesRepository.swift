import DataInterfaces
import Domain

extension InMemoryBackend: NotesRepository {
    public func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote] {
        notesByID.values
            .filter { $0.engagementID == engagementID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func upsert(_ note: CoachNote) async throws -> CoachNote {
        notesByID[note.id] = note
        return note
    }

    public func delete(_ id: Identifier<CoachNote>) async throws {
        guard notesByID.removeValue(forKey: id) != nil else { throw InMemoryStoreError.notFound }
    }
}
