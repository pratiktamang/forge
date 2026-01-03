import Foundation
import GRDB
import Combine

final class TaskRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ task: Task) async throws {
        var taskToSave = task
        taskToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try taskToSave.save(db)
        }
    }

    func delete(_ task: Task) async throws {
        try await database.dbQueue.write { db in
            _ = try task.delete(db)
        }
    }

    func deleteById(_ id: String) async throws {
        try await database.dbQueue.write { db in
            _ = try Task.deleteOne(db, id: id)
        }
    }

    func fetch(id: String) async throws -> Task? {
        try await database.dbQueue.read { db in
            try Task.fetchOne(db, id: id)
        }
    }

    func fetchAll() async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task.fetchAll(db)
        }
    }

    // MARK: - Filtered Queries

    func fetchInbox() async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") == TaskStatus.inbox.rawValue)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchToday() async throws -> [Task] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .filter(
                    // Due today or overdue
                    (Column("dueDate") < tomorrow) ||
                    // Or flagged
                    (Column("isFlagged") == true)
                )
                .order(
                    Column("dueDate").ascNullsLast,
                    Column("createdAt").desc
                )
                .fetchAll(db)
        }
    }

    func fetchUpcoming() async throws -> [Task] {
        let today = Calendar.current.startOfDay(for: Date())

        return try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .filter(Column("dueDate") != nil)
                .filter(Column("dueDate") >= today)
                .order(Column("dueDate").asc)
                .fetchAll(db)
        }
    }

    func fetchFlagged() async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("isFlagged") == true)
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .order(Column("dueDate").ascNullsLast, Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchByProject(_ projectId: String) async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("projectId") == projectId)
                .filter(Column("parentTaskId") == nil) // Only top-level tasks
                .order(Column("sortOrder").asc, Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchByBoardColumn(_ columnId: String) async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("boardColumnId") == columnId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func fetchSubtasks(parentId: String) async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("parentTaskId") == parentId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func fetchCompleted(limit: Int = 50) async throws -> [Task] {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") == TaskStatus.completed.rawValue)
                .order(Column("completedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Batch Operations

    func completeTask(_ task: Task) async throws {
        var updated = task
        updated.status = .completed
        updated.completedAt = Date()
        updated.updatedAt = Date()
        try await save(updated)
    }

    func uncompleteTask(_ task: Task) async throws {
        var updated = task
        updated.status = .next
        updated.completedAt = nil
        updated.updatedAt = Date()
        try await save(updated)
    }

    func moveToColumn(_ task: Task, columnId: String?) async throws {
        var updated = task
        updated.boardColumnId = columnId
        updated.updatedAt = Date()
        try await save(updated)
    }

    func moveToProject(_ task: Task, projectId: String?) async throws {
        var updated = task
        updated.projectId = projectId
        if projectId != nil && updated.status == .inbox {
            updated.status = .next
        }
        updated.updatedAt = Date()
        try await save(updated)
    }

    func updateSortOrder(tasks: [(id: String, sortOrder: Int)]) async throws {
        try await database.dbQueue.write { db in
            for (id, sortOrder) in tasks {
                try db.execute(
                    sql: "UPDATE tasks SET sortOrder = ?, updatedAt = ? WHERE id = ?",
                    arguments: [sortOrder, Date(), id]
                )
            }
        }
    }

    // MARK: - Observation (Reactive)

    func observeInbox() -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        ValueObservation.tracking { db in
            try Task
                .filter(Column("status") == TaskStatus.inbox.rawValue)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func observeToday() -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return ValueObservation.tracking { db in
            try Task
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .filter(
                    (Column("dueDate") < tomorrow) ||
                    (Column("isFlagged") == true)
                )
                .order(
                    Column("dueDate").ascNullsLast,
                    Column("createdAt").desc
                )
                .fetchAll(db)
        }
    }

    func observeUpcoming() -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        let today = Calendar.current.startOfDay(for: Date())

        return ValueObservation.tracking { db in
            try Task
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .filter(Column("dueDate") != nil)
                .filter(Column("dueDate") >= today)
                .order(Column("dueDate").asc)
                .fetchAll(db)
        }
    }

    func observeFlagged() -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        ValueObservation.tracking { db in
            try Task
                .filter(Column("isFlagged") == true)
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .order(Column("dueDate").ascNullsLast)
                .fetchAll(db)
        }
    }

    func observeByProject(_ projectId: String) -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        ValueObservation.tracking { db in
            try Task
                .filter(Column("projectId") == projectId)
                .filter(Column("parentTaskId") == nil)
                .order(Column("sortOrder").asc, Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func observeByBoardColumn(_ columnId: String) -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        ValueObservation.tracking { db in
            try Task
                .filter(Column("boardColumnId") == columnId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func observeTask(id: String) -> ValueObservation<ValueReducers.Fetch<Task?>> {
        ValueObservation.tracking { db in
            try Task.fetchOne(db, id: id)
        }
    }

    // MARK: - Statistics

    func countByStatus() async throws -> [TaskStatus: Int] {
        try await database.dbQueue.read { db in
            var counts: [TaskStatus: Int] = [:]
            let rows = try Row.fetchAll(db, sql: """
                SELECT status, COUNT(*) as count
                FROM tasks
                GROUP BY status
            """)
            for row in rows {
                if let statusStr: String = row["status"],
                   let status = TaskStatus(rawValue: statusStr) {
                    counts[status] = row["count"]
                }
            }
            return counts
        }
    }

    func inboxCount() async throws -> Int {
        try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") == TaskStatus.inbox.rawValue)
                .fetchCount(db)
        }
    }

    // MARK: - Calendar Queries

    func fetchByDate(_ date: Date) async throws -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await database.dbQueue.read { db in
            try Task
                .filter(Column("dueDate") >= startOfDay)
                .filter(Column("dueDate") < endOfDay)
                .filter(Column("parentTaskId") == nil)
                .order(
                    Column("status").asc,
                    Column("createdAt").desc
                )
                .fetchAll(db)
        }
    }

    func fetchByDateRange(from startDate: Date, to endDate: Date) async throws -> [Task] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        return try await database.dbQueue.read { db in
            try Task
                .filter(Column("dueDate") >= start)
                .filter(Column("dueDate") < end)
                .filter(Column("parentTaskId") == nil)
                .order(Column("dueDate").asc, Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchTaskCountsByDate(from startDate: Date, to endDate: Date) async throws -> [Date: Int] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        return try await database.dbQueue.read { db in
            let tasks = try Task
                .filter(Column("dueDate") >= start)
                .filter(Column("dueDate") < end)
                .filter(Column("parentTaskId") == nil)
                .fetchAll(db)

            var counts: [Date: Int] = [:]
            for task in tasks {
                if let dueDate = task.dueDate {
                    let normalizedDate = calendar.startOfDay(for: dueDate)
                    counts[normalizedDate, default: 0] += 1
                }
            }
            return counts
        }
    }

    func observeByDate(_ date: Date) -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return ValueObservation.tracking { db in
            try Task
                .filter(Column("dueDate") >= startOfDay)
                .filter(Column("dueDate") < endOfDay)
                .filter(Column("parentTaskId") == nil)
                .order(
                    Column("status").asc,
                    Column("createdAt").desc
                )
                .fetchAll(db)
        }
    }

    func observeByDateRange(from startDate: Date, to endDate: Date) -> ValueObservation<ValueReducers.Fetch<[Task]>> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        return ValueObservation.tracking { db in
            try Task
                .filter(Column("dueDate") >= start)
                .filter(Column("dueDate") < end)
                .filter(Column("parentTaskId") == nil)
                .order(Column("dueDate").asc, Column("createdAt").desc)
                .fetchAll(db)
        }
    }
}
