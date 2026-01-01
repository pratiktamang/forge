import Foundation
import GRDB
import Combine

final class NoteRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ note: Note) async throws {
        var noteToSave = note
        noteToSave.updatedAt = Date()
        noteToSave.wordCount = note.content.split(separator: " ").count

        try await database.dbQueue.write { db in
            try noteToSave.save(db)
        }

        // Update wiki links
        try await updateWikiLinks(for: noteToSave)
    }

    func delete(_ note: Note) async throws {
        try await database.dbQueue.write { db in
            // Delete associated links
            try db.execute(sql: "DELETE FROM noteLinks WHERE sourceNoteId = ? OR targetNoteId = ?", arguments: [note.id, note.id])
            _ = try note.delete(db)
        }
    }

    func fetch(id: String) async throws -> Note? {
        try await database.dbQueue.read { db in
            try Note.fetchOne(db, id: id)
        }
    }

    func fetchByTitle(_ title: String) async throws -> Note? {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("title") == title)
                .fetchOne(db)
        }
    }

    // MARK: - Queries

    func fetchAll() async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("isDailyNote") == false)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchRecent(limit: Int = 20) async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .order(Column("updatedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchPinned() async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("isPinned") == true)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Daily Notes

    func fetchDailyNote(date: Date) async throws -> Note? {
        let startOfDay = Calendar.current.startOfDay(for: date)

        return try await database.dbQueue.read { db in
            try Note
                .filter(Column("isDailyNote") == true)
                .filter(Column("dailyDate") == startOfDay)
                .fetchOne(db)
        }
    }

    func fetchOrCreateDailyNote(date: Date) async throws -> Note {
        let startOfDay = Calendar.current.startOfDay(for: date)

        // Try to fetch existing
        if let existing = try await fetchDailyNote(date: date) {
            return existing
        }

        // Create new daily note
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        let title = formatter.string(from: date)

        let note = Note(
            title: title,
            content: "# \(title)\n\n",
            isDailyNote: true,
            dailyDate: startOfDay
        )

        try await save(note)
        return note
    }

    func fetchDailyNotes(limit: Int = 30) async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("isDailyNote") == true)
                .order(Column("dailyDate").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Search

    func search(query: String) async throws -> [Note] {
        try await database.dbQueue.read { db in
            // Use FTS for full-text search
            let pattern = FTS5Pattern(matchingAllPrefixesOf: query)

            return try Note
                .joining(required: Note.hasOne(
                    Table("notesFts"),
                    on: sql: "notes.rowid = notesFts.rowid"
                ))
                .filter(sql: "notesFts MATCH ?", arguments: [pattern?.rawPattern ?? query])
                .fetchAll(db)
        }
    }

    func searchSimple(query: String) async throws -> [Note] {
        let pattern = "%\(query)%"

        return try await database.dbQueue.read { db in
            try Note
                .filter(Column("title").like(pattern) || Column("content").like(pattern))
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Wiki Links

    func fetchBacklinks(noteId: String) async throws -> [Note] {
        try await database.dbQueue.read { db in
            let sourceNoteIds = try NoteLink
                .filter(Column("targetNoteId") == noteId)
                .select(Column("sourceNoteId"))
                .fetchAll(db)
                .map { $0.sourceNoteId }

            return try Note
                .filter(sourceNoteIds.contains(Column("id")))
                .fetchAll(db)
        }
    }

    func fetchOutgoingLinks(noteId: String) async throws -> [Note] {
        try await database.dbQueue.read { db in
            let targetNoteIds = try NoteLink
                .filter(Column("sourceNoteId") == noteId)
                .select(Column("targetNoteId"))
                .fetchAll(db)
                .map { $0.targetNoteId }

            return try Note
                .filter(targetNoteIds.contains(Column("id")))
                .fetchAll(db)
        }
    }

    private func updateWikiLinks(for note: Note) async throws {
        let wikiLinks = note.wikiLinks

        try await database.dbQueue.write { db in
            // Remove old links from this note
            try db.execute(sql: "DELETE FROM noteLinks WHERE sourceNoteId = ?", arguments: [note.id])

            // Add new links
            for linkText in wikiLinks {
                // Find target note by title
                if let targetNote = try Note.filter(Column("title") == linkText).fetchOne(db) {
                    let link = NoteLink(
                        sourceNoteId: note.id,
                        targetNoteId: targetNote.id,
                        linkText: linkText
                    )
                    try link.save(db)
                }
            }
        }
    }

    // MARK: - Linked to Entities

    func fetchByProject(_ projectId: String) async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("linkedProjectId") == projectId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchByTask(_ taskId: String) async throws -> [Note] {
        try await database.dbQueue.read { db in
            try Note
                .filter(Column("linkedTaskId") == taskId)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<[Note]> {
        ValueObservation.tracking { db in
            try Note
                .filter(Column("isDailyNote") == false)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    func observeNote(id: String) -> ValueObservation<Note?> {
        ValueObservation.tracking { db in
            try Note.fetchOne(db, id: id)
        }
    }

    func observeDailyNotes() -> ValueObservation<[Note]> {
        ValueObservation.tracking { db in
            try Note
                .filter(Column("isDailyNote") == true)
                .order(Column("dailyDate").desc)
                .limit(30)
                .fetchAll(db)
        }
    }

    func observeBacklinks(noteId: String) -> ValueObservation<[Note]> {
        ValueObservation.tracking { db in
            let sourceNoteIds = try NoteLink
                .filter(Column("targetNoteId") == noteId)
                .fetchAll(db)
                .map { $0.sourceNoteId }

            return try Note
                .filter(sourceNoteIds.contains(Column("id")))
                .fetchAll(db)
        }
    }

    // MARK: - Statistics

    func totalCount() async throws -> Int {
        try await database.dbQueue.read { db in
            try Note.fetchCount(db)
        }
    }

    func totalWordCount() async throws -> Int {
        try await database.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT SUM(wordCount) FROM notes") ?? 0
        }
    }
}
