import Foundation
import GRDB

struct TrackedApp: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var bundleIdentifier: String
    var appName: String
    var category: AppCategory
    var isIgnored: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        bundleIdentifier: String,
        appName: String,
        category: AppCategory = .neutral,
        isIgnored: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.category = category
        self.isIgnored = isIgnored
        self.createdAt = Date()
    }
}

extension TrackedApp: FetchableRecord, PersistableRecord {
    static let databaseTableName = "trackedApps"

    static let activityLogs = hasMany(ActivityLog.self)
}

// MARK: - Activity Log

struct ActivityLog: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var trackedAppId: String
    var windowTitle: String?
    var startTime: Date
    var endTime: Date
    var durationSeconds: Int
    var date: Date
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        trackedAppId: String,
        windowTitle: String? = nil,
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.trackedAppId = trackedAppId
        self.windowTitle = windowTitle
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = Int(endTime.timeIntervalSince(startTime))
        self.date = Calendar.current.startOfDay(for: startTime)
        self.createdAt = Date()
    }
}

extension ActivityLog: FetchableRecord, PersistableRecord {
    static let databaseTableName = "activityLogs"

    static let trackedApp = belongsTo(TrackedApp.self)

    var trackedApp: QueryInterfaceRequest<TrackedApp> {
        request(for: ActivityLog.trackedApp)
    }
}

// MARK: - Enums

enum AppCategory: String, Codable, CaseIterable {
    case productive
    case neutral
    case distracting

    var displayName: String {
        switch self {
        case .productive: return "Productive"
        case .neutral: return "Neutral"
        case .distracting: return "Distracting"
        }
    }

    var color: String {
        switch self {
        case .productive: return "#22C55E"
        case .neutral: return "#94A3B8"
        case .distracting: return "#EF4444"
        }
    }

    var productivityScore: Int {
        switch self {
        case .productive: return 2
        case .neutral: return 0
        case .distracting: return -2
        }
    }
}

// MARK: - Daily Summary

struct DailyProductivity: Identifiable, Codable {
    var id: String
    var date: Date
    var totalTrackedSeconds: Int
    var productiveSeconds: Int
    var neutralSeconds: Int
    var distractingSeconds: Int
    var productivityScore: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        date: Date,
        totalTrackedSeconds: Int = 0,
        productiveSeconds: Int = 0,
        neutralSeconds: Int = 0,
        distractingSeconds: Int = 0
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalTrackedSeconds = totalTrackedSeconds
        self.productiveSeconds = productiveSeconds
        self.neutralSeconds = neutralSeconds
        self.distractingSeconds = distractingSeconds
        self.productivityScore = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func calculateScore() {
        guard totalTrackedSeconds > 0 else {
            productivityScore = 0
            return
        }

        let rawScore = Double(productiveSeconds - distractingSeconds) / Double(totalTrackedSeconds)
        productivityScore = max(0, min(100, (rawScore + 1) * 50))
    }

    var formattedProductiveTime: String {
        formatDuration(productiveSeconds)
    }

    var formattedDistractingTime: String {
        formatDuration(distractingSeconds)
    }

    var formattedTotalTime: String {
        formatDuration(totalTrackedSeconds)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
