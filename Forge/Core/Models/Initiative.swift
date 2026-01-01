import Foundation
import GRDB

struct Initiative: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var description: String?
    var goalId: String?
    var status: InitiativeStatus
    var startDate: Date?
    var targetDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        goalId: String? = nil,
        status: InitiativeStatus = .active,
        startDate: Date? = nil,
        targetDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.goalId = goalId
        self.status = status
        self.startDate = startDate
        self.targetDate = targetDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - GRDB Conformance

extension Initiative: FetchableRecord, PersistableRecord {
    static let databaseTableName = "initiatives"

    static let goal = belongsTo(Goal.self)
    static let projects = hasMany(Project.self)

    var projects: QueryInterfaceRequest<Project> {
        request(for: Initiative.projects)
    }
}

// MARK: - Enums

enum InitiativeStatus: String, Codable, CaseIterable {
    case active
    case onHold
    case completed
    case archived

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .onHold: return "On Hold"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}
