import Foundation
import GRDB
import Combine

final class InitiativeRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ initiative: Initiative) async throws {
        var initiativeToSave = initiative
        initiativeToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try initiativeToSave.save(db)
        }
    }

    func delete(_ initiative: Initiative) async throws {
        try await database.dbQueue.write { db in
            _ = try initiative.delete(db)
        }
    }

    func fetch(id: String) async throws -> Initiative? {
        try await database.dbQueue.read { db in
            try Initiative.fetchOne(db, id: id)
        }
    }

    // MARK: - Queries

    func fetchAll() async throws -> [Initiative] {
        try await database.dbQueue.read { db in
            try Initiative
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchByGoal(_ goalId: String) async throws -> [Initiative] {
        try await database.dbQueue.read { db in
            try Initiative
                .filter(Column("goalId") == goalId)
                .order(Column("sortOrder").asc, Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    func fetchActive() async throws -> [Initiative] {
        try await database.dbQueue.read { db in
            try Initiative
                .filter(Column("status") == InitiativeStatus.active.rawValue)
                .order(Column("targetDate").ascNullsLast)
                .fetchAll(db)
        }
    }

    // MARK: - With Related Data

    struct InitiativeWithProjects {
        let initiative: Initiative
        let projects: [Project]
        let projectCount: Int
        let completedProjectCount: Int
    }

    func fetchWithProjects(id: String) async throws -> InitiativeWithProjects? {
        try await database.dbQueue.read { db in
            guard let initiative = try Initiative.fetchOne(db, id: id) else {
                return nil
            }

            let projects = try Project
                .filter(Column("initiativeId") == id)
                .order(Column("sortOrder").asc)
                .fetchAll(db)

            let completedCount = projects.filter { $0.status == .completed }.count

            return InitiativeWithProjects(
                initiative: initiative,
                projects: projects,
                projectCount: projects.count,
                completedProjectCount: completedCount
            )
        }
    }

    func fetchAllWithProjectCounts() async throws -> [InitiativeWithProjects] {
        try await database.dbQueue.read { db in
            let initiatives = try Initiative
                .filter(Column("status") != InitiativeStatus.archived.rawValue)
                .order(Column("createdAt").desc)
                .fetchAll(db)

            return try initiatives.map { initiative in
                let projects = try Project
                    .filter(Column("initiativeId") == initiative.id)
                    .fetchAll(db)

                let completedCount = projects.filter { $0.status == .completed }.count

                return InitiativeWithProjects(
                    initiative: initiative,
                    projects: projects,
                    projectCount: projects.count,
                    completedProjectCount: completedCount
                )
            }
        }
    }

    // MARK: - Progress Calculation

    func calculateProgress(initiativeId: String) async throws -> Double {
        try await database.dbQueue.read { db in
            let projects = try Project
                .filter(Column("initiativeId") == initiativeId)
                .fetchAll(db)

            guard !projects.isEmpty else { return 0.0 }

            let completedCount = projects.filter { $0.status == .completed }.count
            return Double(completedCount) / Double(projects.count)
        }
    }

    // MARK: - Observation

    func observeAll() -> ValueObservation<[Initiative]> {
        ValueObservation.tracking { db in
            try Initiative
                .filter(Column("status") != InitiativeStatus.archived.rawValue)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func observeByGoal(_ goalId: String) -> ValueObservation<[Initiative]> {
        ValueObservation.tracking { db in
            try Initiative
                .filter(Column("goalId") == goalId)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    func observeInitiative(id: String) -> ValueObservation<Initiative?> {
        ValueObservation.tracking { db in
            try Initiative.fetchOne(db, id: id)
        }
    }

    // MARK: - Timeline Data

    struct TimelineItem {
        let initiative: Initiative
        let goal: Goal?
        let startDate: Date?
        let endDate: Date?
    }

    func fetchTimelineItems(year: Int) async throws -> [TimelineItem] {
        try await database.dbQueue.read { db in
            let initiatives = try Initiative
                .filter(Column("status") != InitiativeStatus.archived.rawValue)
                .fetchAll(db)

            return try initiatives.compactMap { initiative -> TimelineItem? in
                // Filter by year based on dates
                let startYear = initiative.startDate.map { Calendar.current.component(.year, from: $0) }
                let endYear = initiative.targetDate.map { Calendar.current.component(.year, from: $0) }

                let inYear = (startYear == year) || (endYear == year) ||
                             (startYear ?? year <= year && endYear ?? year >= year)

                guard inYear else { return nil }

                let goal: Goal? = try {
                    guard let goalId = initiative.goalId else { return nil }
                    return try Goal.fetchOne(db, id: goalId)
                }()

                return TimelineItem(
                    initiative: initiative,
                    goal: goal,
                    startDate: initiative.startDate,
                    endDate: initiative.targetDate
                )
            }
        }
    }
}
