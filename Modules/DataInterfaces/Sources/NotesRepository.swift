import Domain

/// CRUD access to a coach's private `CoachNote`s about a client engagement.
public protocol NotesRepository: Sendable {
    /// One-shot fetch of all notes for an engagement, oldest first.
    func notes(forEngagement engagementID: Identifier<Engagement>) async throws -> [CoachNote]
    func upsert(_ note: CoachNote) async throws -> CoachNote
    func delete(_ id: Identifier<CoachNote>) async throws
}
