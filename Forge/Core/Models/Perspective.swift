import Foundation
import GRDB

struct Perspective: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var icon: String
    var color: String?
    var sortOrder: Int
    var filterConfig: FilterConfig
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        icon: String = "line.3.horizontal.decrease.circle",
        color: String? = nil,
        sortOrder: Int = 0,
        filterConfig: FilterConfig = FilterConfig()
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.filterConfig = filterConfig
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Filter Configuration

struct FilterConfig: Codable, Equatable, Hashable {
    var statuses: [TaskStatus]?
    var priorities: [Priority]?
    var projectIds: [String]?
    var tagIds: [String]?
    var isFlagged: Bool?
    var hasDueDate: Bool?
    var isOverdue: Bool?
    var dueDateRange: DateRangeFilter?
    var deferDateRange: DateRangeFilter?
    var showCompleted: Bool
    var sortBy: SortOption
    var sortAscending: Bool

    init(
        statuses: [TaskStatus]? = nil,
        priorities: [Priority]? = nil,
        projectIds: [String]? = nil,
        tagIds: [String]? = nil,
        isFlagged: Bool? = nil,
        hasDueDate: Bool? = nil,
        isOverdue: Bool? = nil,
        dueDateRange: DateRangeFilter? = nil,
        deferDateRange: DateRangeFilter? = nil,
        showCompleted: Bool = false,
        sortBy: SortOption = .dueDate,
        sortAscending: Bool = true
    ) {
        self.statuses = statuses
        self.priorities = priorities
        self.projectIds = projectIds
        self.tagIds = tagIds
        self.isFlagged = isFlagged
        self.hasDueDate = hasDueDate
        self.isOverdue = isOverdue
        self.dueDateRange = dueDateRange
        self.deferDateRange = deferDateRange
        self.showCompleted = showCompleted
        self.sortBy = sortBy
        self.sortAscending = sortAscending
    }

    var isEmpty: Bool {
        statuses == nil &&
        priorities == nil &&
        projectIds == nil &&
        tagIds == nil &&
        isFlagged == nil &&
        hasDueDate == nil &&
        isOverdue == nil &&
        dueDateRange == nil &&
        deferDateRange == nil
    }
}

// MARK: - Date Range Filter

enum DateRangeFilter: String, Codable, CaseIterable {
    case today
    case tomorrow
    case thisWeek
    case nextWeek
    case thisMonth
    case overdue
    case noDate

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .nextWeek: return "Next Week"
        case .thisMonth: return "This Month"
        case .overdue: return "Overdue"
        case .noDate: return "No Date"
        }
    }

    func dateRange() -> (start: Date?, end: Date?) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch self {
        case .today:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            return (today, tomorrow)

        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
            let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!
            return (tomorrow, dayAfter)

        case .thisWeek:
            let weekStart = calendar.startOfWeek(for: today)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return (weekStart, weekEnd)

        case .nextWeek:
            let weekStart = calendar.startOfWeek(for: today)
            let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            let nextWeekEnd = calendar.date(byAdding: .day, value: 14, to: weekStart)!
            return (nextWeekStart, nextWeekEnd)

        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return (monthStart, nextMonth)

        case .overdue:
            return (nil, today)

        case .noDate:
            return (nil, nil)
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, Codable, CaseIterable {
    case dueDate
    case deferDate
    case priority
    case title
    case createdAt
    case updatedAt

    var displayName: String {
        switch self {
        case .dueDate: return "Due Date"
        case .deferDate: return "Defer Date"
        case .priority: return "Priority"
        case .title: return "Title"
        case .createdAt: return "Created"
        case .updatedAt: return "Updated"
        }
    }
}

// MARK: - GRDB Conformance

extension Perspective: FetchableRecord, PersistableRecord {
    static let databaseTableName = "perspectives"

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let title = Column(CodingKeys.title)
        static let icon = Column(CodingKeys.icon)
        static let color = Column(CodingKeys.color)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let filterConfig = Column(CodingKeys.filterConfig)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Default Perspectives

extension Perspective {
    static let defaults: [Perspective] = [
        Perspective(
            title: "High Priority",
            icon: "exclamationmark.circle.fill",
            color: "#EF4444",
            sortOrder: 0,
            filterConfig: FilterConfig(
                priorities: [.high],
                showCompleted: false,
                sortBy: .dueDate,
                sortAscending: true
            )
        ),
        Perspective(
            title: "Due This Week",
            icon: "calendar.badge.clock",
            color: "#3B82F6",
            sortOrder: 1,
            filterConfig: FilterConfig(
                dueDateRange: .thisWeek,
                showCompleted: false,
                sortBy: .dueDate,
                sortAscending: true
            )
        ),
        Perspective(
            title: "Waiting For",
            icon: "person.fill.questionmark",
            color: "#F59E0B",
            sortOrder: 2,
            filterConfig: FilterConfig(
                statuses: [.waiting],
                showCompleted: false,
                sortBy: .dueDate,
                sortAscending: true
            )
        ),
        Perspective(
            title: "Someday/Maybe",
            icon: "moon.stars.fill",
            color: "#8B5CF6",
            sortOrder: 3,
            filterConfig: FilterConfig(
                statuses: [.someday],
                showCompleted: false,
                sortBy: .createdAt,
                sortAscending: false
            )
        ),
    ]
}
