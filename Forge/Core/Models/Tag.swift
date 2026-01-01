import Foundation
import GRDB

struct Tag: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var color: String?
    var tagType: TagType
    var sortOrder: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        color: String? = nil,
        tagType: TagType = .tag,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.tagType = tagType
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    var displayName: String {
        switch tagType {
        case .context:
            return "@\(name)"
        case .area:
            return "[\(name)]"
        case .tag:
            return "#\(name)"
        }
    }
}

// MARK: - GRDB Conformance

extension Tag: FetchableRecord, PersistableRecord {
    static let databaseTableName = "tags"

    static let taskTags = hasMany(TaskTag.self)
    static let tasks = hasMany(Task.self, through: taskTags, using: TaskTag.task)
    static let noteTags = hasMany(NoteTag.self)
    static let notes = hasMany(Note.self, through: noteTags, using: NoteTag.note)
}

// MARK: - Enums

enum TagType: String, Codable, CaseIterable {
    case tag
    case context
    case area

    var displayName: String {
        switch self {
        case .tag: return "Tag"
        case .context: return "Context"
        case .area: return "Area"
        }
    }

    var prefix: String {
        switch self {
        case .tag: return "#"
        case .context: return "@"
        case .area: return ""
        }
    }
}
