import Foundation
import GRDB
import Combine

final class ActivityRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - TrackedApp Operations

    func saveTrackedApp(_ app: TrackedApp) async throws {
        try await database.dbQueue.write { db in
            try app.save(db)
        }
    }

    func fetchTrackedApp(id: String) async throws -> TrackedApp? {
        try await database.dbQueue.read { db in
            try TrackedApp.fetchOne(db, id: id)
        }
    }

    func fetchTrackedApp(bundleId: String) async throws -> TrackedApp? {
        try await database.dbQueue.read { db in
            try TrackedApp
                .filter(Column("bundleIdentifier") == bundleId)
                .fetchOne(db)
        }
    }

    func fetchAllTrackedApps() async throws -> [TrackedApp] {
        try await database.dbQueue.read { db in
            try TrackedApp
                .order(Column("appName").asc)
                .fetchAll(db)
        }
    }

    func getOrCreateTrackedApp(bundleId: String, appName: String) async throws -> TrackedApp {
        if let existing = try await fetchTrackedApp(bundleId: bundleId) {
            return existing
        }

        let newApp = TrackedApp(bundleIdentifier: bundleId, appName: appName)
        try await saveTrackedApp(newApp)
        return newApp
    }

    func updateAppCategory(_ app: TrackedApp, category: AppCategory) async throws {
        var updated = app
        updated.category = category
        try await saveTrackedApp(updated)
    }

    func setAppIgnored(_ app: TrackedApp, ignored: Bool) async throws {
        var updated = app
        updated.isIgnored = ignored
        try await saveTrackedApp(updated)
    }

    // MARK: - ActivityLog Operations

    func saveActivityLog(_ log: ActivityLog) async throws {
        try await database.dbQueue.write { db in
            try log.save(db)
        }
    }

    func fetchLogsForDate(_ date: Date) async throws -> [ActivityLog] {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return try await database.dbQueue.read { db in
            try ActivityLog
                .filter(Column("date") == normalizedDate)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    func fetchLogsForDateRange(from startDate: Date, to endDate: Date) async throws -> [ActivityLog] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try await database.dbQueue.read { db in
            try ActivityLog
                .filter(Column("date") >= start)
                .filter(Column("date") <= end)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    func deleteActivityLog(_ log: ActivityLog) async throws {
        try await database.dbQueue.write { db in
            _ = try log.delete(db)
        }
    }

    // MARK: - Aggregated Stats

    func fetchAppDurationsForDate(_ date: Date) async throws -> [(TrackedApp, Int)] {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        return try await database.dbQueue.read { db in
            let logs = try ActivityLog
                .filter(Column("date") == normalizedDate)
                .fetchAll(db)

            // Group by app and sum durations
            var durationByAppId: [String: Int] = [:]
            for log in logs {
                durationByAppId[log.trackedAppId, default: 0] += log.durationSeconds
            }

            // Fetch apps and pair with durations
            var result: [(TrackedApp, Int)] = []
            for (appId, duration) in durationByAppId {
                if let app = try TrackedApp.fetchOne(db, id: appId), !app.isIgnored {
                    result.append((app, duration))
                }
            }

            // Sort by duration descending
            return result.sorted { $0.1 > $1.1 }
        }
    }

    func calculateDailyProductivity(for date: Date) async throws -> DailyProductivity {
        let appDurations = try await fetchAppDurationsForDate(date)

        var totalSeconds = 0
        var productiveSeconds = 0
        var neutralSeconds = 0
        var distractingSeconds = 0

        for (app, duration) in appDurations {
            totalSeconds += duration
            switch app.category {
            case .productive:
                productiveSeconds += duration
            case .neutral:
                neutralSeconds += duration
            case .distracting:
                distractingSeconds += duration
            }
        }

        var productivity = DailyProductivity(
            date: date,
            totalTrackedSeconds: totalSeconds,
            productiveSeconds: productiveSeconds,
            neutralSeconds: neutralSeconds,
            distractingSeconds: distractingSeconds
        )
        productivity.calculateScore()

        return productivity
    }

    // MARK: - Observation

    func observeLogsForDate(_ date: Date) -> ValueObservation<ValueReducers.Fetch<[ActivityLog]>> {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return ValueObservation.tracking { db in
            try ActivityLog
                .filter(Column("date") == normalizedDate)
                .order(Column("startTime").desc)
                .fetchAll(db)
        }
    }

    func observeTrackedApps() -> ValueObservation<ValueReducers.Fetch<[TrackedApp]>> {
        ValueObservation.tracking { db in
            try TrackedApp
                .order(Column("appName").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Statistics

    func totalTrackedTimeForDate(_ date: Date) async throws -> Int {
        let logs = try await fetchLogsForDate(date)
        return logs.reduce(0) { $0 + $1.durationSeconds }
    }

    func fetchUncategorizedApps() async throws -> [TrackedApp] {
        try await database.dbQueue.read { db in
            try TrackedApp
                .filter(Column("category") == AppCategory.neutral.rawValue)
                .filter(Column("isIgnored") == false)
                .order(Column("appName").asc)
                .fetchAll(db)
        }
    }
}
