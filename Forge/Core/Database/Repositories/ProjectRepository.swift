import Foundation
import GRDB
import Combine

final class ProjectRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ project: Project) async throws {
        var projectToSave = project
        projectToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try projectToSave.save(db)
        }
    }

    func delete(_ project: Project) async throws {
        try await database.dbQueue.write { db in
            _ = try project.delete(db)
        }
    }

    func fetch(id: String) async throws -> Project? {
        try await database.dbQueue.read { db in
            try Project.fetchOne(db, id: id)
        }
    }

    func fetchAll() async throws -> [Project] {
        try await database.dbQueue.read { db in
            try Project
                .filter(Column("status") != ProjectStatus.archived.rawValue)
                .order(Column("sortOrder").asc, Column("title").asc)
                .fetchAll(db)
        }
    }

    func fetchActive() async throws -> [Project] {
        try await database.dbQueue.read { db in
            try Project
                .filter(Column("status") == ProjectStatus.active.rawValue)
                .order(Column("sortOrder").asc, Column("title").asc)
                .fetchAll(db)
        }
    }

    // MARK: - With Task Counts

    struct ProjectWithTaskCount: Decodable, FetchableRecord {
        var project: Project
        var taskCount: Int
        var completedCount: Int
    }

    // Project has 10 columns, so annotated counts start at index 10
    private static let taskCountIndex = 10
    private static let completedCountIndex = 11

    func fetchProjectWithTaskCount(id: String) async throws -> ProjectWithTaskCount? {
        try await database.dbQueue.read { db in
            let request = Project
                .filter(Column("id") == id)
                .annotated(with:
                    Project.tasks.filter(Column("status") != TaskStatus.completed.rawValue).count,
                    Project.tasks.filter(Column("status") == TaskStatus.completed.rawValue).count
                )

            return try Row.fetchOne(db, request).map { row in
                ProjectWithTaskCount(
                    project: try Project(row: row),
                    taskCount: row[Self.taskCountIndex] as Int,
                    completedCount: row[Self.completedCountIndex] as Int
                )
            }
        }
    }

    func fetchAllWithTaskCounts() async throws -> [ProjectWithTaskCount] {
        try await database.dbQueue.read { db in
            let request = Project
                .filter(Column("status") != ProjectStatus.archived.rawValue)
                .annotated(with:
                    Project.tasks.count,
                    Project.tasks.filter(Column("status") == TaskStatus.completed.rawValue).count
                )
                .order(Column("sortOrder").asc)

            return try Row.fetchAll(db, request).map { row in
                ProjectWithTaskCount(
                    project: try Project(row: row),
                    taskCount: row[Self.taskCountIndex] as Int,
                    completedCount: row[Self.completedCountIndex] as Int
                )
            }
        }
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Project]>> {
        ValueObservation.tracking { db in
            try Project
                .filter(Column("status") != ProjectStatus.archived.rawValue)
                .order(Column("sortOrder").asc, Column("title").asc)
                .fetchAll(db)
        }
    }

    func observeActive() -> ValueObservation<ValueReducers.Fetch<[Project]>> {
        ValueObservation.tracking { db in
            try Project
                .filter(Column("status") == ProjectStatus.active.rawValue)
                .order(Column("sortOrder").asc, Column("title").asc)
                .fetchAll(db)
        }
    }

    func observeActiveWithTaskCounts() -> ValueObservation<ValueReducers.Fetch<[ProjectWithTaskCount]>> {
        ValueObservation.tracking { db in
            let request = Project
                .filter(Column("status") == ProjectStatus.active.rawValue)
                .annotated(with:
                    Project.tasks.filter(Column("status") != TaskStatus.completed.rawValue).count,
                    Project.tasks.filter(Column("status") == TaskStatus.completed.rawValue).count
                )
                .order(Column("sortOrder").asc, Column("title").asc)

            return try Row.fetchAll(db, request).map { row in
                ProjectWithTaskCount(
                    project: try Project(row: row),
                    taskCount: row[ProjectRepository.taskCountIndex] as Int,
                    completedCount: row[ProjectRepository.completedCountIndex] as Int
                )
            }
        }
    }

    func observeProject(id: String) -> ValueObservation<ValueReducers.Fetch<Project?>> {
        ValueObservation.tracking { db in
            try Project.fetchOne(db, id: id)
        }
    }
}
