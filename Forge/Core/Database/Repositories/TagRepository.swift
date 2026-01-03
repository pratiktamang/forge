import Foundation
import GRDB
import Combine

final class TagRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ tag: Tag) async throws {
        try await database.dbQueue.write { db in
            try tag.save(db)
        }
    }

    func delete(_ tag: Tag) async throws {
        try await database.dbQueue.write { db in
            _ = try tag.delete(db)
        }
    }

    func fetch(id: String) async throws -> Tag? {
        try await database.dbQueue.read { db in
            try Tag.fetchOne(db, id: id)
        }
    }

    // MARK: - Queries

    func fetchAll() async throws -> [Tag] {
        try await database.dbQueue.read { db in
            try Tag
                .order(Column("sortOrder").asc, Column("name").asc)
                .fetchAll(db)
        }
    }

    func fetchByType(_ type: TagType) async throws -> [Tag] {
        try await database.dbQueue.read { db in
            try Tag
                .filter(Column("tagType") == type.rawValue)
                .order(Column("sortOrder").asc, Column("name").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Task-Tag Operations

    func fetchTagsForTask(_ taskId: String) async throws -> [Tag] {
        try await database.dbQueue.read { db in
            try Tag
                .joining(required: Tag.taskTags.filter(Column("taskId") == taskId))
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func addTagToTask(tagId: String, taskId: String) async throws {
        try await database.dbQueue.write { db in
            let taskTag = TaskTag(taskId: taskId, tagId: tagId)
            try taskTag.insert(db)
        }
    }

    func removeTagFromTask(tagId: String, taskId: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM taskTag WHERE taskId = ? AND tagId = ?",
                arguments: [taskId, tagId]
            )
        }
    }

    func setTagsForTask(tagIds: [String], taskId: String) async throws {
        try await database.dbQueue.write { db in
            // Remove existing tags
            try db.execute(
                sql: "DELETE FROM taskTag WHERE taskId = ?",
                arguments: [taskId]
            )

            // Add new tags
            for tagId in tagIds {
                let taskTag = TaskTag(taskId: taskId, tagId: tagId)
                try taskTag.insert(db)
            }
        }
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Tag]>> {
        ValueObservation.tracking { db in
            try Tag
                .order(Column("sortOrder").asc, Column("name").asc)
                .fetchAll(db)
        }
    }

    func observeTagsForTask(_ taskId: String) -> ValueObservation<ValueReducers.Fetch<[Tag]>> {
        ValueObservation.tracking { db in
            try Tag
                .joining(required: Tag.taskTags.filter(Column("taskId") == taskId))
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }
}
