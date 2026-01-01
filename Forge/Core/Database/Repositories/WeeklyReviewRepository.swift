import Foundation
import GRDB
import Combine

final class WeeklyReviewRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ review: WeeklyReview) async throws {
        var reviewToSave = review
        reviewToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try reviewToSave.save(db)
        }
    }

    func fetch(id: String) async throws -> WeeklyReview? {
        try await database.dbQueue.read { db in
            try WeeklyReview.fetchOne(db, id: id)
        }
    }

    func fetchAll() async throws -> [WeeklyReview] {
        try await database.dbQueue.read { db in
            try WeeklyReview
                .order(Column("weekStart").desc)
                .fetchAll(db)
        }
    }

    func fetchForWeek(_ weekStart: Date) async throws -> WeeklyReview? {
        let normalized = Calendar.current.startOfWeek(for: weekStart)
        return try await database.dbQueue.read { db in
            try WeeklyReview
                .filter(Column("weekStart") == normalized)
                .fetchOne(db)
        }
    }

    func fetchRecent(limit: Int = 10) async throws -> [WeeklyReview] {
        try await database.dbQueue.read { db in
            try WeeklyReview
                .filter(Column("completedAt") != nil)
                .order(Column("weekStart").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func getOrCreateForWeek(_ weekStart: Date) async throws -> WeeklyReview {
        if let existing = try await fetchForWeek(weekStart) {
            return existing
        }

        let newReview = WeeklyReview(weekStart: weekStart)
        try await save(newReview)
        return newReview
    }

    func delete(_ review: WeeklyReview) async throws {
        try await database.dbQueue.write { db in
            _ = try review.delete(db)
        }
    }

    // MARK: - Statistics for Review

    func fetchWeeklyStats(weekStart: Date) async throws -> WeeklyStats {
        let calendar = Calendar.current
        let start = calendar.startOfWeek(for: weekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!

        return try await database.dbQueue.read { db in
            // Tasks completed this week
            let tasksCompleted = try Task
                .filter(Column("status") == TaskStatus.completed.rawValue)
                .filter(Column("completedAt") >= start)
                .filter(Column("completedAt") < end)
                .fetchCount(db)

            // Tasks created this week
            let tasksCreated = try Task
                .filter(Column("createdAt") >= start)
                .filter(Column("createdAt") < end)
                .fetchCount(db)

            // Inbox count
            let inboxCount = try Task
                .filter(Column("status") == TaskStatus.inbox.rawValue)
                .fetchCount(db)

            // Overdue tasks
            let today = calendar.startOfDay(for: Date())
            let overdueTasks = try Task
                .filter(Column("status") != TaskStatus.completed.rawValue)
                .filter(Column("status") != TaskStatus.cancelled.rawValue)
                .filter(Column("dueDate") != nil)
                .filter(Column("dueDate") < today)
                .fetchCount(db)

            // Active projects count
            let activeProjects = try Project
                .filter(Column("status") == "active")
                .fetchCount(db)

            // Stalled projects (no tasks completed in last 7 days)
            let projectsWithActivity = try Row.fetchAll(db, sql: """
                SELECT DISTINCT t.projectId
                FROM tasks t
                WHERE t.status = 'completed'
                AND t.completedAt >= ?
                AND t.projectId IS NOT NULL
            """, arguments: [start])

            let activeProjectIds = projectsWithActivity.compactMap { $0["projectId"] as? String }
            let stalledProjects = try Project
                .filter(Column("status") == "active")
                .filter(!activeProjectIds.contains(Column("id")))
                .fetchCount(db)

            return WeeklyStats(
                tasksCompleted: tasksCompleted,
                tasksCreated: tasksCreated,
                inboxCount: inboxCount,
                overdueTasks: overdueTasks,
                activeProjects: activeProjects,
                stalledProjects: stalledProjects
            )
        }
    }

    func fetchHabitStats(weekStart: Date) async throws -> HabitWeeklyStats {
        let calendar = Calendar.current
        let start = calendar.startOfWeek(for: weekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!

        return try await database.dbQueue.read { db in
            // Get all active habits
            let habits = try Habit
                .filter(Column("isArchived") == false)
                .fetchAll(db)

            guard !habits.isEmpty else {
                return HabitWeeklyStats(
                    totalHabits: 0,
                    completionsThisWeek: 0,
                    possibleCompletions: 0,
                    completionRate: 0
                )
            }

            // Count completions this week
            let completions = try HabitCompletion
                .filter(Column("completedDate") >= start)
                .filter(Column("completedDate") < end)
                .fetchCount(db)

            // Estimate possible completions (simplified: daily habits * 7)
            let dailyHabits = habits.filter { $0.frequencyType == .daily }.count
            let weeklyHabits = habits.filter { $0.frequencyType == .weekly }.count
            let possibleCompletions = (dailyHabits * 7) + weeklyHabits

            let completionRate = possibleCompletions > 0
                ? Double(completions) / Double(possibleCompletions) * 100
                : 0

            return HabitWeeklyStats(
                totalHabits: habits.count,
                completionsThisWeek: completions,
                possibleCompletions: possibleCompletions,
                completionRate: completionRate
            )
        }
    }

    func fetchCompletedTasks(weekStart: Date) async throws -> [Task] {
        let calendar = Calendar.current
        let start = calendar.startOfWeek(for: weekStart)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!

        return try await database.dbQueue.read { db in
            try Task
                .filter(Column("status") == TaskStatus.completed.rawValue)
                .filter(Column("completedAt") >= start)
                .filter(Column("completedAt") < end)
                .order(Column("completedAt").desc)
                .fetchAll(db)
        }
    }

    func fetchStalledProjects() async throws -> [Project] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        return try await database.dbQueue.read { db in
            // Get projects with recent activity
            let projectsWithActivity = try Row.fetchAll(db, sql: """
                SELECT DISTINCT t.projectId
                FROM tasks t
                WHERE t.status = 'completed'
                AND t.completedAt >= ?
                AND t.projectId IS NOT NULL
            """, arguments: [oneWeekAgo])

            let activeProjectIds = projectsWithActivity.compactMap { $0["projectId"] as? String }

            return try Project
                .filter(Column("status") == "active")
                .filter(!activeProjectIds.contains(Column("id")))
                .order(Column("title").asc)
                .fetchAll(db)
        }
    }

    func fetchActiveGoals() async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("status") == GoalStatus.active.rawValue)
                .order(Column("goalType").asc, Column("year").desc, Column("quarter").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Observation

    func observeCurrentWeekReview() -> ValueObservation<ValueReducers.Fetch<WeeklyReview?>> {
        let weekStart = Calendar.current.startOfWeek(for: Date())
        return ValueObservation.tracking { db in
            try WeeklyReview
                .filter(Column("weekStart") == weekStart)
                .fetchOne(db)
        }
    }

    func observeRecentReviews(limit: Int = 5) -> ValueObservation<ValueReducers.Fetch<[WeeklyReview]>> {
        ValueObservation.tracking { db in
            try WeeklyReview
                .order(Column("weekStart").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}

// MARK: - Stats Structs

struct WeeklyStats {
    let tasksCompleted: Int
    let tasksCreated: Int
    let inboxCount: Int
    let overdueTasks: Int
    let activeProjects: Int
    let stalledProjects: Int
}

struct HabitWeeklyStats {
    let totalHabits: Int
    let completionsThisWeek: Int
    let possibleCompletions: Int
    let completionRate: Double
}
