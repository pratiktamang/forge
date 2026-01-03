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
                t.column("color", .text)
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

    // MARK: - Seed Data

    #if DEBUG
    func resetAndSeed() throws {
        print("🗑️ Clearing all data...")
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM taskTags")
            try db.execute(sql: "DELETE FROM noteTags")
            try db.execute(sql: "DELETE FROM noteLinks")
            try db.execute(sql: "DELETE FROM habitCompletions")
            try db.execute(sql: "DELETE FROM activityLogs")
            try db.execute(sql: "DELETE FROM trackedApps")
            try db.execute(sql: "DELETE FROM tasks")
            try db.execute(sql: "DELETE FROM boardColumns")
            try db.execute(sql: "DELETE FROM boards")
            try db.execute(sql: "DELETE FROM notes")
            try db.execute(sql: "DELETE FROM tags")
            try db.execute(sql: "DELETE FROM habits")
            try db.execute(sql: "DELETE FROM weeklyReviews")
            try db.execute(sql: "DELETE FROM perspectives")
            try db.execute(sql: "DELETE FROM projects")
            try db.execute(sql: "DELETE FROM initiatives")
            try db.execute(sql: "DELETE FROM goals")
        }
        print("✅ Data cleared")
        try seedSampleData()
    }

    func seedSampleData() throws {
        print("🌱 Checking if seed needed...")
        try dbQueue.write { db in
            // Check if already seeded
            let projectCount = try Project.fetchCount(db)
            print("🌱 Existing project count: \(projectCount)")
            guard projectCount == 0 else {
                print("🌱 Already seeded, skipping")
                return
            }

            let now = Date()

            // Create sample projects
            let projects = [
                Project(id: "proj-1", title: "Website Redesign", description: "Modernize the company website", color: "007AFF", icon: "globe"),
                Project(id: "proj-2", title: "Mobile App", description: "Build iOS app for customers", color: "34C759", icon: "iphone"),
                Project(id: "proj-3", title: "Learn Swift", description: "Personal learning project", color: "AF52DE", icon: "book.fill"),
            ]
            for project in projects {
                try project.insert(db)
            }

            // Create sample tasks
            let tasks: [Task] = [
                // Website Redesign tasks
                Task(id: "task-1", title: "Design homepage mockup", projectId: "proj-1", status: .next, priority: .high, dueDate: Calendar.current.date(byAdding: .day, value: 2, to: now)),
                Task(id: "task-2", title: "Set up new hosting", projectId: "proj-1", status: .next, priority: .medium),
                Task(id: "task-3", title: "Migrate content", projectId: "proj-1", status: .inbox),

                // Mobile App tasks
                Task(id: "task-4", title: "Create project in Xcode", projectId: "proj-2", status: .completed),
                Task(id: "task-5", title: "Design app icon", projectId: "proj-2", status: .next, priority: .low, dueDate: Calendar.current.date(byAdding: .day, value: 7, to: now)),
                Task(id: "task-6", title: "Implement login screen", projectId: "proj-2", status: .next, isFlagged: true),

                // Learn Swift tasks
                Task(id: "task-7", title: "Complete SwiftUI tutorial", projectId: "proj-3", status: .next, dueDate: now),
                Task(id: "task-8", title: "Build sample project", projectId: "proj-3", status: .inbox),

                // Inbox tasks (no project)
                Task(id: "task-9", title: "Call dentist", status: .inbox, priority: .high),
                Task(id: "task-10", title: "Buy groceries", status: .inbox, isFlagged: true),
                Task(id: "task-11", title: "Review quarterly goals", status: .inbox, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: now)),
            ]
            for task in tasks {
                try task.insert(db)
            }

            // Create sample tags
            let tags = [
                Tag(id: "tag-1", name: "urgent", color: "FF3B30", tagType: .context),
                Tag(id: "tag-2", name: "waiting", color: "FF9500", tagType: .context),
                Tag(id: "tag-3", name: "home", color: "5AC8FA", tagType: .area),
                Tag(id: "tag-4", name: "work", color: "007AFF", tagType: .area),
            ]
            for tag in tags {
                try tag.insert(db)
            }

            // Create quarterly goals
            let currentYear = Calendar.current.component(.year, from: now)
            let goals = [
                // Q1 Goals - first two completed
                Goal(id: "goal-q1-1", title: "Ship MVP to beta users", goalType: .quarterly, year: currentYear, quarter: 1, status: .completed, progress: 1.0, color: "EF4444"),
                Goal(id: "goal-q1-2", title: "Set up CI/CD pipeline", goalType: .quarterly, year: currentYear, quarter: 1, status: .completed, progress: 1.0, color: "3B82F6"),
                Goal(id: "goal-q1-3", title: "Onboard first 10 users", goalType: .quarterly, year: currentYear, quarter: 1, status: .active, progress: 0.6, color: "F59E0B"),
                Goal(id: "goal-q1-4", title: "Implement analytics", goalType: .quarterly, year: currentYear, quarter: 1, status: .active, progress: 0.2, color: "8B5CF6"),

                // Q2 Goals
                Goal(id: "goal-q2-1", title: "Launch iOS app on App Store", goalType: .quarterly, year: currentYear, quarter: 2, status: .active, color: "10B981"),
                Goal(id: "goal-q2-2", title: "Reach 100 active users", goalType: .quarterly, year: currentYear, quarter: 2, status: .active, color: "F59E0B"),
                Goal(id: "goal-q2-3", title: "Implement sync engine", goalType: .quarterly, year: currentYear, quarter: 2, status: .active, color: "3B82F6"),

                // Q3 Goals
                Goal(id: "goal-q3-1", title: "Launch Mac app", goalType: .quarterly, year: currentYear, quarter: 3, status: .active, color: "6366F1"),
                Goal(id: "goal-q3-2", title: "First paying customer", goalType: .quarterly, year: currentYear, quarter: 3, status: .active, color: "10B981"),
                Goal(id: "goal-q3-3", title: "Add collaboration features", goalType: .quarterly, year: currentYear, quarter: 3, status: .active, color: "EC4899"),
            ]
            for goal in goals {
                try goal.insert(db)
            }

            // Create a sample habit
            let habit = Habit(
                id: "habit-1",
                title: "Daily exercise",
                description: "30 minutes of movement",
                frequencyType: .daily,
                color: "34C759",
                icon: "figure.run"
            )
            try habit.insert(db)

            // Create a sample note
            let note = Note(
                id: "note-1",
                title: "Project Ideas",
                content: "# Project Ideas\n\n- Build a habit tracker\n- Create a recipe app\n- Automate home lighting"
            )
            try note.insert(db)

            print("✅ Seeded sample data")
        }
    }
    #endif
}
