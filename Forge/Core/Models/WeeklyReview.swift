import Foundation
import GRDB

struct WeeklyReview: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var weekStart: Date
    var wins: String?
    var challenges: String?
    var lessons: String?
    var nextWeekFocus: String?
    var tasksCompleted: Int
    var tasksCreated: Int
    var habitsCompletionRate: Double?
    var productivityScore: Double?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        weekStart: Date,
        wins: String? = nil,
        challenges: String? = nil,
        lessons: String? = nil,
        nextWeekFocus: String? = nil,
        tasksCompleted: Int = 0,
        tasksCreated: Int = 0,
        habitsCompletionRate: Double? = nil,
        productivityScore: Double? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.weekStart = Calendar.current.startOfWeek(for: weekStart)
        self.wins = wins
        self.challenges = challenges
        self.lessons = lessons
        self.nextWeekFocus = nextWeekFocus
        self.tasksCompleted = tasksCompleted
        self.tasksCreated = tasksCreated
        self.habitsCompletionRate = habitsCompletionRate
        self.productivityScore = productivityScore
        self.completedAt = completedAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var weekEndDate: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    var weekRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        let end = formatter.string(from: weekEndDate)
        return "\(start) - \(end)"
    }

    mutating func complete() {
        completedAt = Date()
        updatedAt = Date()
    }
}

// MARK: - GRDB Conformance

extension WeeklyReview: FetchableRecord, PersistableRecord {
    static let databaseTableName = "weeklyReviews"
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return self.date(byAdding: .day, value: 6, to: start) ?? date
    }
}

// MARK: - Review Step

enum ReviewStep: Int, CaseIterable {
    case inbox
    case completed
    case projects
    case goals
    case habits
    case reflection
    case planning
    case summary

    var title: String {
        switch self {
        case .inbox: return "Process Inbox"
        case .completed: return "Celebrate Wins"
        case .projects: return "Review Projects"
        case .goals: return "Check Goals"
        case .habits: return "Habit Progress"
        case .reflection: return "Reflect"
        case .planning: return "Plan Ahead"
        case .summary: return "Summary"
        }
    }

    var description: String {
        switch self {
        case .inbox: return "Clear out your inbox by processing all items"
        case .completed: return "Review what you accomplished this week"
        case .projects: return "Check on active projects and clear stalled ones"
        case .goals: return "Review progress on your goals"
        case .habits: return "See how consistent you've been"
        case .reflection: return "Capture wins, challenges, and lessons"
        case .planning: return "Set your focus for next week"
        case .summary: return "Review your weekly stats"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .completed: return "checkmark.circle"
        case .projects: return "folder"
        case .goals: return "target"
        case .habits: return "repeat"
        case .reflection: return "lightbulb"
        case .planning: return "calendar"
        case .summary: return "chart.bar"
        }
    }

    var next: ReviewStep? {
        let allCases = ReviewStep.allCases
        guard let index = allCases.firstIndex(of: self),
              index + 1 < allCases.count else { return nil }
        return allCases[index + 1]
    }

    var previous: ReviewStep? {
        let allCases = ReviewStep.allCases
        guard let index = allCases.firstIndex(of: self),
              index > 0 else { return nil }
        return allCases[index - 1]
    }
}
