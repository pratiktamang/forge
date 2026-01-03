import Foundation
import GRDB

struct Goal: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var description: String?
    var goalType: GoalType
    var year: Int
    var quarter: Int?
    var parentGoalId: String?
    var status: GoalStatus
    var progress: Double
    var targetDate: Date?
    var color: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        goalType: GoalType,
        year: Int,
        quarter: Int? = nil,
        parentGoalId: String? = nil,
        status: GoalStatus = .active,
        progress: Double = 0.0,
        targetDate: Date? = nil,
        color: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.goalType = goalType
        self.year = year
        self.quarter = quarter
        self.parentGoalId = parentGoalId
        self.status = status
        self.progress = progress
        self.targetDate = targetDate
        self.color = color
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var displayPeriod: String {
        switch goalType {
        case .yearly:
            return "\(year)"
        case .quarterly:
            return "Q\(quarter ?? 1) \(year)"
        }
    }
}

// MARK: - GRDB Conformance

extension Goal: FetchableRecord, PersistableRecord {
    static let databaseTableName = "goals"

    static let parentGoal = belongsTo(Goal.self, key: "parentGoal", using: ForeignKey(["parentGoalId"]))
    static let childGoals = hasMany(Goal.self, key: "childGoals", using: ForeignKey(["parentGoalId"]))
    static let initiatives = hasMany(Initiative.self)
    static let habits = hasMany(Habit.self)

    var childGoals: QueryInterfaceRequest<Goal> {
        request(for: Goal.childGoals)
    }

    var initiatives: QueryInterfaceRequest<Initiative> {
        request(for: Goal.initiatives)
    }
}

// MARK: - Enums

enum GoalType: String, Codable, CaseIterable {
    case yearly
    case quarterly

    var displayName: String {
        switch self {
        case .yearly: return "Yearly"
        case .quarterly: return "Quarterly"
        }
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case active
    case completed
    case archived

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}
