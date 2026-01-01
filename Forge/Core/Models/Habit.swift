import Foundation
import GRDB

struct Habit: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var description: String?
    var frequencyType: FrequencyType
    var frequencyDays: [Int]?
    var timesPerPeriod: Int
    var goalId: String?
    var reminderTime: String?
    var color: String?
    var icon: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String? = nil,
        frequencyType: FrequencyType = .daily,
        frequencyDays: [Int]? = nil,
        timesPerPeriod: Int = 1,
        goalId: String? = nil,
        reminderTime: String? = nil,
        color: String? = nil,
        icon: String? = "checkmark.circle",
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.frequencyType = frequencyType
        self.frequencyDays = frequencyDays
        self.timesPerPeriod = timesPerPeriod
        self.goalId = goalId
        self.reminderTime = reminderTime
        self.color = color
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var frequencyDaysString: String? {
        get { frequencyDays.map { $0.map(String.init).joined(separator: ",") } }
        set { frequencyDays = newValue?.split(separator: ",").compactMap { Int($0) } }
    }

    func isDueOn(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)

        switch frequencyType {
        case .daily:
            return true
        case .weekly:
            return frequencyDays?.contains(weekday) ?? false
        case .custom:
            return frequencyDays?.contains(weekday) ?? false
        }
    }
}

// MARK: - GRDB Conformance

extension Habit: FetchableRecord, PersistableRecord {
    static let databaseTableName = "habits"

    enum Columns {
        static let frequencyDays = Column(CodingKeys.frequencyDays)
    }

    static let goal = belongsTo(Goal.self)
    static let completions = hasMany(HabitCompletion.self)

    var completions: QueryInterfaceRequest<HabitCompletion> {
        request(for: Habit.completions)
    }

    // Custom encoding for frequencyDays array
    func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["title"] = title
        container["description"] = description
        container["frequencyType"] = frequencyType.rawValue
        container["frequencyDays"] = frequencyDays.map { $0.map(String.init).joined(separator: ",") }
        container["timesPerPeriod"] = timesPerPeriod
        container["goalId"] = goalId
        container["reminderTime"] = reminderTime
        container["color"] = color
        container["icon"] = icon
        container["isArchived"] = isArchived
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    init(row: Row) throws {
        id = row["id"]
        title = row["title"]
        description = row["description"]
        frequencyType = FrequencyType(rawValue: row["frequencyType"]) ?? .daily
        if let daysString: String = row["frequencyDays"] {
            frequencyDays = daysString.split(separator: ",").compactMap { Int($0) }
        } else {
            frequencyDays = nil
        }
        timesPerPeriod = row["timesPerPeriod"]
        goalId = row["goalId"]
        reminderTime = row["reminderTime"]
        color = row["color"]
        icon = row["icon"]
        isArchived = row["isArchived"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
    }
}

// MARK: - Habit Completion

struct HabitCompletion: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String
    var habitId: String
    var completedDate: Date
    var notes: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        habitId: String,
        completedDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.habitId = habitId
        self.completedDate = Calendar.current.startOfDay(for: completedDate)
        self.notes = notes
        self.createdAt = Date()
    }

    static let habit = belongsTo(Habit.self)
}

// MARK: - Enums

enum FrequencyType: String, Codable, CaseIterable {
    case daily
    case weekly
    case custom

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .custom: return "Custom"
        }
    }
}
