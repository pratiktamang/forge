import Foundation
import GRDB

struct BoardColumn: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var boardId: String
    var title: String
    var color: String?
    var sortOrder: Int
    var wipLimit: Int?
    var mapsToStatus: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        boardId: String,
        title: String,
        color: String? = nil,
        sortOrder: Int = 0,
        wipLimit: Int? = nil,
        mapsToStatus: String? = nil
    ) {
        self.id = id
        self.boardId = boardId
        self.title = title
        self.color = color
        self.sortOrder = sortOrder
        self.wipLimit = wipLimit
        self.mapsToStatus = mapsToStatus
        self.createdAt = Date()
    }

    var mappedStatus: TaskStatus? {
        guard let mapsToStatus = mapsToStatus else { return nil }
        return TaskStatus(rawValue: mapsToStatus)
    }
}

// MARK: - GRDB Conformance

extension BoardColumn: FetchableRecord, PersistableRecord {
    static let databaseTableName = "boardColumns"

    static let board = belongsTo(Board.self)
    static let tasks = hasMany(Task.self).order(Column("sortOrder"))

    var tasks: QueryInterfaceRequest<Task> {
        request(for: BoardColumn.tasks)
    }
}
