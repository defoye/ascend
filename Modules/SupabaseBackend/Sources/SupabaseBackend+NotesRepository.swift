import DataInterfaces
import Domain
import Foundation

extension SupabaseBackend: NotesRepository {
    public func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote] {
        let rows = try await notesTable.fetchAll { $0.eq("engagement_id", value: engagementID.rawValue) }
        return rows.map(\.toDomain).sorted { $0.createdAt < $1.createdAt }
    }

    public func upsert(_ note: CoachNote) async throws -> CoachNote {
        try await notesTable.upsert(CoachNoteRow(domain: note))
        return note
    }

    public func delete(_ id: Identifier<CoachNote>) async throws {
        try await notesTable.delete(id: id.rawValue)
    }

    var notesTable: SupabaseTable<CoachNoteRow> {
        SupabaseTable(client: client, queue: queue, table: "coach_notes")
    }
}
