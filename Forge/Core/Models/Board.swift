import Foundation
import GRDB

struct Board: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var projectId: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        projectId: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.title = title
        self.projectId = projectId
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Create a board with Fizzy-inspired default columns
    static func createWithDefaultColumns(title: String, projectId: String? = nil) -> (Board, [BoardColumn]) {
        let board = Board(title: title, projectId: projectId, isDefault: true)

        let columns = [
            BoardColumn(boardId: board.id, title: "Not Now", color: "#9CA3AF", sortOrder: 0, mapsToStatus: "someday"),
            BoardColumn(boardId: board.id, title: "To Do", color: "#6B7280", sortOrder: 1, mapsToStatus: "next"),
            BoardColumn(boardId: board.id, title: "In Progress", color: "#3B82F6", sortOrder: 2, mapsToStatus: "next"),
            BoardColumn(boardId: board.id, title: "Done", color: "#22C55E", sortOrder: 3, mapsToStatus: "completed")
        ]

        return (board, columns)
    }
}

// MARK: - GRDB Conformance

extension Board: FetchableRecord, PersistableRecord {
    static let databaseTableName = "boards"

    static let project = belongsTo(Project.self)
    static let columns = hasMany(BoardColumn.self).order(Column("sortOrder"))

    var columns: QueryInterfaceRequest<BoardColumn> {
        request(for: Board.columns)
    }
}
