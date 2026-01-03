import Foundation
import GRDB

struct Task: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var notes: String?
    var projectId: String?
    var boardColumnId: String?
    var parentTaskId: String?
    var status: TaskStatus
    var dueDate: Date?
    var completedAt: Date?
    var isFlagged: Bool
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var recurrenceRule: String?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        projectId: String? = nil,
        boardColumnId: String? = nil,
        parentTaskId: String? = nil,
        status: TaskStatus = .inbox,
        dueDate: Date? = nil,
        isFlagged: Bool = false,
        estimatedMinutes: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.projectId = projectId
        self.boardColumnId = boardColumnId
        self.parentTaskId = parentTaskId
        self.status = status
        self.dueDate = dueDate
        self.completedAt = nil
        self.isFlagged = isFlagged
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = nil
        self.recurrenceRule = nil
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func complete() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }

    mutating func uncomplete() {
        status = .next
        completedAt = nil
        updatedAt = Date()
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, status != .completed else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueSoon: Bool {
        guard let dueDate = dueDate else { return false }
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        return dueDate <= threeDaysFromNow && dueDate >= Date()
    }
}

// MARK: - GRDB Conformance

extension Task: FetchableRecord, PersistableRecord {
    static let databaseTableName = "tasks"

    // Associations
    static let project = belongsTo(Project.self)
    static let boardColumn = belongsTo(BoardColumn.self)
    static let parentTask = belongsTo(Task.self, key: "parentTask", using: ForeignKey(["parentTaskId"]))
    static let subtasks = hasMany(Task.self, key: "subtasks", using: ForeignKey(["parentTaskId"]))
    static let taskTags = hasMany(TaskTag.self)
    static let tags = hasMany(Tag.self, through: taskTags, using: TaskTag.tag)

    var project: QueryInterfaceRequest<Project> {
        request(for: Task.project)
    }

    var subtasks: QueryInterfaceRequest<Task> {
        request(for: Task.subtasks)
    }

    var tags: QueryInterfaceRequest<Tag> {
        request(for: Task.tags)
    }
}

// MARK: - Enums

enum TaskStatus: String, Codable, CaseIterable {
    case inbox
    case next
    case waiting
    case scheduled
    case someday
    case completed
    case cancelled

    var displayName: String {
        switch self {
        case .inbox: return "Inbox"
        case .next: return "Next"
        case .waiting: return "Waiting"
        case .scheduled: return "Scheduled"
        case .someday: return "Someday"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .next: return "arrow.right.circle"
        case .waiting: return "hourglass"
        case .scheduled: return "calendar"
        case .someday: return "moon.stars"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
}

// MARK: - Task-Tag Junction

struct TaskTag: Codable, FetchableRecord, PersistableRecord {
    var taskId: String
    var tagId: String

    static let task = belongsTo(Task.self)
    static let tag = belongsTo(Tag.self)
}
