import Foundation
import GRDB

final class AppDatabase {
    static let shared = AppDatabase()

    private(set) var dbQueue: DatabaseQueue!

    private init() {}

    // MARK: - Setup

    func setup() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Forge", isDirectory: true)

        try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)

        let dbPath = appFolder.appendingPathComponent("forge.sqlite").path

        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }
        #endif

        dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
        try runMigrations()
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // v1: Initial schema
        migrator.registerMigration("v1") { db in
            // Goals
            try db.create(table: "goals") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("goalType", .text).notNull()
                t.column("year", .integer).notNull()
                t.column("quarter", .integer)
                t.column("parentGoalId", .text).references("goals", onDelete: .setNull)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("progress", .double).defaults(to: 0.0)
                t.column("targetDate", .date)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Initiatives
            try db.create(table: "initiatives") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("goalId", .text).references("goals", onDelete: .setNull)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("startDate", .date)
                t.column("targetDate", .date)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Projects
            try db.create(table: "projects") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("initiativeId", .text).references("initiatives", onDelete: .setNull)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("color", .text)
                t.column("icon", .text)
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Tags
            try db.create(table: "tags") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
                t.column("color", .text)
                t.column("tagType", .text).notNull().defaults(to: "tag")
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }

            // Boards
            try db.create(table: "boards") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("projectId", .text).references("projects", onDelete: .cascade)
                t.column("isDefault", .boolean).defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Board Columns
            try db.create(table: "boardColumns") { t in
                t.column("id", .text).primaryKey()
                t.column("boardId", .text).notNull().references("boards", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("color", .text)
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("wipLimit", .integer)
                t.column("mapsToStatus", .text)
                t.column("createdAt", .datetime).notNull()
            }

            // Tasks
            try db.create(table: "tasks") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("notes", .text)
                t.column("projectId", .text).references("projects", onDelete: .setNull)
                t.column("boardColumnId", .text).references("boardColumns", onDelete: .setNull)
                t.column("parentTaskId", .text).references("tasks", onDelete: .cascade)
                t.column("status", .text).notNull().defaults(to: "inbox")
                t.column("priority", .text).notNull().defaults(to: "none")
                t.column("deferDate", .date)
                t.column("dueDate", .date)
                t.column("completedAt", .datetime)
                t.column("isFlagged", .boolean).defaults(to: false)
                t.column("estimatedMinutes", .integer)
                t.column("actualMinutes", .integer)
                t.column("recurrenceRule", .text)
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Task-Tag junction
            try db.create(table: "taskTags") { t in
                t.column("taskId", .text).notNull().references("tasks", onDelete: .cascade)
                t.column("tagId", .text).notNull().references("tags", onDelete: .cascade)
                t.primaryKey(["taskId", "tagId"])
            }

            // Notes
            try db.create(table: "notes") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull().defaults(to: "")
                t.column("linkedProjectId", .text).references("projects", onDelete: .setNull)
                t.column("linkedTaskId", .text).references("tasks", onDelete: .setNull)
                t.column("isDailyNote", .boolean).defaults(to: false)
                t.column("dailyDate", .date).unique()
                t.column("isPinned", .boolean).defaults(to: false)
                t.column("wordCount", .integer).defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Note-Tag junction
            try db.create(table: "noteTags") { t in
                t.column("noteId", .text).notNull().references("notes", onDelete: .cascade)
                t.column("tagId", .text).notNull().references("tags", onDelete: .cascade)
                t.primaryKey(["noteId", "tagId"])
            }

            // Note links (wiki-style)
            try db.create(table: "noteLinks") { t in
                t.column("id", .text).primaryKey()
                t.column("sourceNoteId", .text).notNull().references("notes", onDelete: .cascade)
                t.column("targetNoteId", .text).notNull().references("notes", onDelete: .cascade)
                t.column("linkText", .text)
                t.column("createdAt", .datetime).notNull()
            }

            // Full-text search for notes
            try db.execute(sql: """
                CREATE VIRTUAL TABLE notesFts USING fts5(title, content, content='notes', content_rowid='rowid')
            """)

            // Habits
            try db.create(table: "habits") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("description", .text)
                t.column("frequencyType", .text).notNull()
                t.column("frequencyDays", .text)
                t.column("timesPerPeriod", .integer).defaults(to: 1)
                t.column("goalId", .text).references("goals", onDelete: .setNull)
                t.column("reminderTime", .text)
                t.column("color", .text)
                t.column("icon", .text)
                t.column("isArchived", .boolean).defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Habit completions
            try db.create(table: "habitCompletions") { t in
                t.column("id", .text).primaryKey()
                t.column("habitId", .text).notNull().references("habits", onDelete: .cascade)
                t.column("completedDate", .date).notNull()
                t.column("notes", .text)
                t.column("createdAt", .datetime).notNull()
                t.uniqueKey(["habitId", "completedDate"])
            }

            // Activity tracking
            try db.create(table: "trackedApps") { t in
                t.column("id", .text).primaryKey()
                t.column("bundleIdentifier", .text).notNull().unique()
                t.column("appName", .text).notNull()
                t.column("category", .text).defaults(to: "neutral")
                t.column("isIgnored", .boolean).defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "activityLogs") { t in
                t.column("id", .text).primaryKey()
                t.column("trackedAppId", .text).notNull().references("trackedApps", onDelete: .cascade)
                t.column("windowTitle", .text)
                t.column("startTime", .datetime).notNull()
                t.column("endTime", .datetime).notNull()
                t.column("durationSeconds", .integer).notNull()
                t.column("date", .date).notNull()
                t.column("createdAt", .datetime).notNull()
            }

            // Weekly reviews
            try db.create(table: "weeklyReviews") { t in
                t.column("id", .text).primaryKey()
                t.column("weekStart", .date).notNull().unique()
                t.column("wins", .text)
                t.column("challenges", .text)
                t.column("lessons", .text)
                t.column("nextWeekFocus", .text)
                t.column("tasksCompleted", .integer).defaults(to: 0)
                t.column("tasksCreated", .integer).defaults(to: 0)
                t.column("habitsCompletionRate", .double)
                t.column("productivityScore", .double)
                t.column("completedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Custom perspectives
            try db.create(table: "perspectives") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("icon", .text).notNull()
                t.column("color", .text)
                t.column("sortOrder", .integer).defaults(to: 0)
                t.column("filterConfig", .text).notNull() // JSON encoded
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Create indices
            try db.create(index: "idx_tasks_project", on: "tasks", columns: ["projectId"])
            try db.create(index: "idx_tasks_status", on: "tasks", columns: ["status"])
            try db.create(index: "idx_tasks_dueDate", on: "tasks", columns: ["dueDate"])
            try db.create(index: "idx_tasks_deferDate", on: "tasks", columns: ["deferDate"])
            try db.create(index: "idx_notes_dailyDate", on: "notes", columns: ["dailyDate"])
            try db.create(index: "idx_activityLogs_date", on: "activityLogs", columns: ["date"])
            try db.create(index: "idx_habitCompletions_date", on: "habitCompletions", columns: ["completedDate"])
        }

        try migrator.migrate(dbQueue)
    }
}
