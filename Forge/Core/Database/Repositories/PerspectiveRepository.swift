import Foundation
import GRDB
import Combine

final class PerspectiveRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ perspective: Perspective) async throws {
        var perspectiveToSave = perspective
        perspectiveToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try perspectiveToSave.save(db)
        }
    }

    func fetch(id: String) async throws -> Perspective? {
        try await database.dbQueue.read { db in
            try Perspective.fetchOne(db, id: id)
        }
    }

    func fetchAll() async throws -> [Perspective] {
        try await database.dbQueue.read { db in
            try Perspective
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func delete(_ perspective: Perspective) async throws {
        try await database.dbQueue.write { db in
            _ = try perspective.delete(db)
        }
    }

    func deleteById(_ id: String) async throws {
        try await database.dbQueue.write { db in
            _ = try Perspective.deleteOne(db, id: id)
        }
    }

    // MARK: - Sorting

    func updateSortOrder(perspectives: [(id: String, sortOrder: Int)]) async throws {
        try await database.dbQueue.write { db in
            for (id, sortOrder) in perspectives {
                try db.execute(
                    sql: "UPDATE perspectives SET sortOrder = ?, updatedAt = ? WHERE id = ?",
                    arguments: [sortOrder, Date(), id]
                )
            }
        }
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Perspective]>> {
        ValueObservation.tracking { db in
            try Perspective
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func observePerspective(id: String) -> ValueObservation<ValueReducers.Fetch<Perspective?>> {
        ValueObservation.tracking { db in
            try Perspective.fetchOne(db, id: id)
        }
    }

    // MARK: - Filter Execution

    func fetchTasks(for perspective: Perspective) async throws -> [Task] {
        let config = perspective.filterConfig
        return try await database.dbQueue.read { db in
            var request = Task.all()

            // Status filter
            if let statuses = config.statuses, !statuses.isEmpty {
                let statusValues = statuses.map { $0.rawValue }
                request = request.filter(statusValues.contains(Column("status")))
            } else if !config.showCompleted {
                request = request
                    .filter(Column("status") != TaskStatus.completed.rawValue)
                    .filter(Column("status") != TaskStatus.cancelled.rawValue)
            }

            // Project filter
            if let projectIds = config.projectIds, !projectIds.isEmpty {
                request = request.filter(projectIds.contains(Column("projectId")))
            }

            // Flagged filter
            if let isFlagged = config.isFlagged {
                request = request.filter(Column("isFlagged") == isFlagged)
            }

            // Has due date filter
            if let hasDueDate = config.hasDueDate {
                if hasDueDate {
                    request = request.filter(Column("dueDate") != nil)
                } else {
                    request = request.filter(Column("dueDate") == nil)
                }
            }

            // Due date range filter
            if let dueDateRange = config.dueDateRange {
                let (start, end) = dueDateRange.dateRange()
                if dueDateRange == .noDate {
                    request = request.filter(Column("dueDate") == nil)
                } else if dueDateRange == .overdue {
                    let today = Calendar.current.startOfDay(for: Date())
                    request = request.filter(Column("dueDate") < today)
                } else if let start = start, let end = end {
                    request = request
                        .filter(Column("dueDate") >= start)
                        .filter(Column("dueDate") < end)
                }
            }

            // Only top-level tasks
            request = request.filter(Column("parentTaskId") == nil)

            // Sorting
            switch config.sortBy {
            case .dueDate:
                request = config.sortAscending
                    ? request.order(Column("dueDate").ascNullsLast)
                    : request.order(Column("dueDate").desc)
            case .title:
                request = config.sortAscending
                    ? request.order(Column("title").asc)
                    : request.order(Column("title").desc)
            case .createdAt:
                request = config.sortAscending
                    ? request.order(Column("createdAt").asc)
                    : request.order(Column("createdAt").desc)
            case .updatedAt:
                request = config.sortAscending
                    ? request.order(Column("updatedAt").asc)
                    : request.order(Column("updatedAt").desc)
            }

            return try request.fetchAll(db)
        }
    }

    // MARK: - Default Perspectives

    func ensureDefaultPerspectives() async throws {
        let existing = try await fetchAll()
        guard existing.isEmpty else { return }

        for perspective in Perspective.defaults {
            try await save(perspective)
        }
    }
}
