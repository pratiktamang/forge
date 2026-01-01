import Foundation
import GRDB

struct Project: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var description: String?
    var initiativeId: String?
    var status: ProjectStatus
    var color: String?
    var icon: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        initiativeId: String? = nil,
        status: ProjectStatus = .active,
        color: String? = nil,
        icon: String? = "folder",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.initiativeId = initiativeId
        self.status = status
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - GRDB Conformance

extension Project: FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"

    static let initiative = belongsTo(Initiative.self)
    static let tasks = hasMany(Task.self)
    static let boards = hasMany(Board.self)

    var tasks: QueryInterfaceRequest<Task> {
        request(for: Project.tasks)
    }

    var boards: QueryInterfaceRequest<Board> {
        request(for: Project.boards)
    }
}

// MARK: - Enums

enum ProjectStatus: String, Codable, CaseIterable {
    case active
    case onHold
    case completed
    case archived
    case someday

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .archived: return "Archived"
        case .someday: return "Someday"
        }
    }
}
