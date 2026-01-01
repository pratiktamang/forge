import Foundation
import GRDB
import Combine

final class GoalRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ goal: Goal) async throws {
        var goalToSave = goal
        goalToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try goalToSave.save(db)
        }
    }

    func delete(_ goal: Goal) async throws {
        try await database.dbQueue.write { db in
            _ = try goal.delete(db)
        }
    }

    func fetch(id: String) async throws -> Goal? {
        try await database.dbQueue.read { db in
            try Goal.fetchOne(db, id: id)
        }
    }

    // MARK: - Queries

    func fetchAll() async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .order(Column("year").desc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    func fetchByYear(_ year: Int) async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("year") == year)
                .order(Column("goalType").asc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    func fetchYearlyGoals(year: Int) async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("year") == year)
                .filter(Column("goalType") == GoalType.yearly.rawValue)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    func fetchQuarterlyGoals(year: Int, quarter: Int) async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("year") == year)
                .filter(Column("quarter") == quarter)
                .filter(Column("goalType") == GoalType.quarterly.rawValue)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    func fetchChildGoals(parentId: String) async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("parentGoalId") == parentId)
                .order(Column("quarter").asc)
                .fetchAll(db)
        }
    }

    func fetchActiveGoals() async throws -> [Goal] {
        try await database.dbQueue.read { db in
            try Goal
                .filter(Column("status") == GoalStatus.active.rawValue)
                .order(Column("year").desc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Grouped by Year

    struct GoalsByYear {
        let year: Int
        let yearlyGoals: [Goal]
        let quarterlyGoals: [Int: [Goal]] // Quarter -> Goals
    }

    func fetchGroupedByYear() async throws -> [GoalsByYear] {
        try await database.dbQueue.read { db in
            let allGoals = try Goal
                .order(Column("year").desc, Column("quarter").asc)
                .fetchAll(db)

            // Group by year
            let grouped = Dictionary(grouping: allGoals) { $0.year }

            return grouped.keys.sorted(by: >).map { year in
                let yearGoals = grouped[year] ?? []
                let yearly = yearGoals.filter { $0.goalType == .yearly }
                let quarterly = Dictionary(grouping: yearGoals.filter { $0.goalType == .quarterly }) { $0.quarter ?? 0 }

                return GoalsByYear(year: year, yearlyGoals: yearly, quarterlyGoals: quarterly)
            }
        }
    }

    // MARK: - Progress Calculation

    func updateProgress(_ goal: Goal) async throws {
        // Calculate progress based on child goals or linked initiatives
        var updated = goal

        let childGoals = try await fetchChildGoals(parentId: goal.id)
        if !childGoals.isEmpty {
            let totalProgress = childGoals.reduce(0.0) { $0 + $1.progress }
            updated.progress = totalProgress / Double(childGoals.count)
        }

        try await save(updated)
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Goal]>> {
        ValueObservation.tracking { db in
            try Goal
                .order(Column("year").desc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    func observeByYear(_ year: Int) -> ValueObservation<ValueReducers.Fetch<[Goal]>> {
        ValueObservation.tracking { db in
            try Goal
                .filter(Column("year") == year)
                .order(Column("goalType").asc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    func observeGoal(id: String) -> ValueObservation<ValueReducers.Fetch<Goal?>> {
        ValueObservation.tracking { db in
            try Goal.fetchOne(db, id: id)
        }
    }

    func observeActiveGoals() -> ValueObservation<ValueReducers.Fetch<[Goal]>> {
        ValueObservation.tracking { db in
            try Goal
                .filter(Column("status") == GoalStatus.active.rawValue)
                .order(Column("year").desc, Column("quarter").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Statistics

    func currentYearStats() async throws -> (total: Int, completed: Int, inProgress: Int) {
        let currentYear = Calendar.current.component(.year, from: Date())

        return try await database.dbQueue.read { db in
            let goals = try Goal
                .filter(Column("year") == currentYear)
                .fetchAll(db)

            let completed = goals.filter { $0.status == .completed }.count
            let inProgress = goals.filter { $0.status == .active }.count

            return (goals.count, completed, inProgress)
        }
    }
}
