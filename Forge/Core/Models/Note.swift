import Foundation
import GRDB

struct Note: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var content: String
    var linkedProjectId: String?
    var linkedTaskId: String?
    var isDailyNote: Bool
    var dailyDate: Date?
    var isPinned: Bool
    var wordCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String = "",
        linkedProjectId: String? = nil,
        linkedTaskId: String? = nil,
        isDailyNote: Bool = false,
        dailyDate: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.linkedProjectId = linkedProjectId
        self.linkedTaskId = linkedTaskId
        self.isDailyNote = isDailyNote
        self.dailyDate = dailyDate
        self.isPinned = isPinned
        self.wordCount = content.split(separator: " ").count
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func updateContent(_ newContent: String) {
        content = newContent
        wordCount = newContent.split(separator: " ").count
        updatedAt = Date()
    }

    /// Extract wiki-style links [[like this]] from content
    var wikiLinks: [String] {
        let pattern = #"\[\[([^\]]+)\]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
    }
}

// MARK: - GRDB Conformance

extension Note: FetchableRecord, PersistableRecord {
    static let databaseTableName = "notes"

    static let project = belongsTo(Project.self, using: ForeignKey(["linkedProjectId"]))
    static let task = belongsTo(Task.self, using: ForeignKey(["linkedTaskId"]))
    static let noteTags = hasMany(NoteTag.self)
    static let tags = hasMany(Tag.self, through: noteTags, using: NoteTag.tag)
    static let outgoingLinks = hasMany(NoteLink.self, key: "outgoingLinks", using: ForeignKey(["sourceNoteId"]))
    static let incomingLinks = hasMany(NoteLink.self, key: "incomingLinks", using: ForeignKey(["targetNoteId"]))

    var tags: QueryInterfaceRequest<Tag> {
        request(for: Note.tags)
    }

    var backlinks: QueryInterfaceRequest<NoteLink> {
        request(for: Note.incomingLinks)
    }
}

// MARK: - Note-Tag Junction

struct NoteTag: Codable, FetchableRecord, PersistableRecord {
    var noteId: String
    var tagId: String

    static let note = belongsTo(Note.self)
    static let tag = belongsTo(Tag.self)
}

// MARK: - Note Links

struct NoteLink: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var sourceNoteId: String
    var targetNoteId: String
    var linkText: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sourceNoteId: String,
        targetNoteId: String,
        linkText: String? = nil
    ) {
        self.id = id
        self.sourceNoteId = sourceNoteId
        self.targetNoteId = targetNoteId
        self.linkText = linkText
        self.createdAt = Date()
    }

    static let sourceNote = belongsTo(Note.self, key: "sourceNote", using: ForeignKey(["sourceNoteId"]))
    static let targetNote = belongsTo(Note.self, key: "targetNote", using: ForeignKey(["targetNoteId"]))
}
