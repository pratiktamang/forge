import Foundation
import GRDB
import Combine

final class BoardRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - Board CRUD

    func save(_ board: Board) async throws {
        var boardToSave = board
        boardToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try boardToSave.save(db)
        }
    }

    func delete(_ board: Board) async throws {
        try await database.dbQueue.write { db in
            _ = try board.delete(db)
        }
    }

    func fetch(id: String) async throws -> Board? {
        try await database.dbQueue.read { db in
            try Board.fetchOne(db, id: id)
        }
    }

    func fetchByProject(_ projectId: String) async throws -> [Board] {
        try await database.dbQueue.read { db in
            try Board
                .filter(Column("projectId") == projectId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    func fetchDefaultBoard(projectId: String) async throws -> Board? {
        try await database.dbQueue.read { db in
            try Board
                .filter(Column("projectId") == projectId)
                .filter(Column("isDefault") == true)
                .fetchOne(db)
        }
    }

    // MARK: - Column CRUD

    func saveColumn(_ column: BoardColumn) async throws {
        try await database.dbQueue.write { db in
            try column.save(db)
        }
    }

    func deleteColumn(_ column: BoardColumn) async throws {
        try await database.dbQueue.write { db in
            // First, move all tasks in this column to no column
            try db.execute(
                sql: "UPDATE tasks SET boardColumnId = NULL WHERE boardColumnId = ?",
                arguments: [column.id]
            )
            _ = try column.delete(db)
        }
    }

    func fetchColumns(boardId: String) async throws -> [BoardColumn] {
        try await database.dbQueue.read { db in
            try BoardColumn
                .filter(Column("boardId") == boardId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func updateColumnOrder(columns: [(id: String, sortOrder: Int)]) async throws {
        try await database.dbQueue.write { db in
            for (id, sortOrder) in columns {
                try db.execute(
                    sql: "UPDATE boardColumns SET sortOrder = ? WHERE id = ?",
                    arguments: [sortOrder, id]
                )
            }
        }
    }

    // MARK: - Create Board with Default Columns

    func createBoardWithDefaultColumns(title: String, projectId: String) async throws -> Board {
        let (board, columns) = Board.createWithDefaultColumns(title: title, projectId: projectId)

        try await database.dbQueue.write { db in
            try board.save(db)
            for column in columns {
                try column.save(db)
            }
        }

        return board
    }

    // MARK: - Observation

    func observeBoard(id: String) -> ValueObservation<ValueReducers.Fetch<Board?>> {
        ValueObservation.tracking { db in
            try Board.fetchOne(db, id: id)
        }
    }

    func observeColumns(boardId: String) -> ValueObservation<ValueReducers.Fetch<[BoardColumn]>> {
        ValueObservation.tracking { db in
            try BoardColumn
                .filter(Column("boardId") == boardId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func observeBoardsByProject(_ projectId: String) -> ValueObservation<ValueReducers.Fetch<[Board]>> {
        ValueObservation.tracking { db in
            try Board
                .filter(Column("projectId") == projectId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Board with Columns and Tasks

    struct BoardWithData {
        let board: Board
        let columns: [ColumnWithTasks]
    }

    struct ColumnWithTasks {
        let column: BoardColumn
        let tasks: [Task]
    }

    func fetchBoardWithData(boardId: String) async throws -> BoardWithData? {
        try await database.dbQueue.read { db in
            guard let board = try Board.fetchOne(db, id: boardId) else {
                return nil
            }

            let columns = try BoardColumn
                .filter(Column("boardId") == boardId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)

            let columnsWithTasks = try columns.map { column in
                let tasks = try Task
                    .filter(Column("boardColumnId") == column.id)
                    .order(Column("sortOrder").asc)
                    .fetchAll(db)
                return ColumnWithTasks(column: column, tasks: tasks)
            }

            return BoardWithData(board: board, columns: columnsWithTasks)
        }
    }
}
