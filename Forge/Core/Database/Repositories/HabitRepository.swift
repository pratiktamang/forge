import Foundation
import GRDB
import Combine

// MARK: - Streak Info

struct HabitStreakInfo {
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let completionRate: Double
    let lastCompletedDate: Date?
}

// MARK: - Repository

final class HabitRepository {
    private let database: AppDatabase

    init(database: AppDatabase = .shared) {
        self.database = database
    }

    // MARK: - CRUD Operations

    func save(_ habit: Habit) async throws {
        var habitToSave = habit
        habitToSave.updatedAt = Date()
        try await database.dbQueue.write { db in
            try habitToSave.save(db)
        }
    }

    func delete(_ habit: Habit) async throws {
        try await database.dbQueue.write { db in
            _ = try habit.delete(db)
        }
    }

    func deleteById(_ id: String) async throws {
        try await database.dbQueue.write { db in
            _ = try Habit.deleteOne(db, id: id)
        }
    }

    func fetch(id: String) async throws -> Habit? {
        try await database.dbQueue.read { db in
            try Habit.fetchOne(db, id: id)
        }
    }

    func fetchAll() async throws -> [Habit] {
        try await database.dbQueue.read { db in
            try Habit
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchActive() async throws -> [Habit] {
        try await database.dbQueue.read { db in
            try Habit
                .filter(Column("isArchived") == false)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func fetchArchived() async throws -> [Habit] {
        try await database.dbQueue.read { db in
            try Habit
                .filter(Column("isArchived") == true)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
    }

    // MARK: - Completion Operations

    func saveCompletion(_ completion: HabitCompletion) async throws {
        try await database.dbQueue.write { db in
            try completion.save(db)
        }
    }

    func deleteCompletion(habitId: String, date: Date) async throws {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        try await database.dbQueue.write { db in
            try HabitCompletion
                .filter(Column("habitId") == habitId)
                .filter(Column("completedDate") == normalizedDate)
                .deleteAll(db)
        }
    }

    func fetchCompletions(habitId: String) async throws -> [HabitCompletion] {
        try await database.dbQueue.read { db in
            try HabitCompletion
                .filter(Column("habitId") == habitId)
                .order(Column("completedDate").desc)
                .fetchAll(db)
        }
    }

    func fetchCompletions(habitId: String, from startDate: Date, to endDate: Date) async throws -> [HabitCompletion] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        return try await database.dbQueue.read { db in
            try HabitCompletion
                .filter(Column("habitId") == habitId)
                .filter(Column("completedDate") >= start)
                .filter(Column("completedDate") <= end)
                .order(Column("completedDate").desc)
                .fetchAll(db)
        }
    }

    func fetchCompletionDates(habitId: String) async throws -> Set<Date> {
        let completions = try await fetchCompletions(habitId: habitId)
        return Set(completions.map { Calendar.current.startOfDay(for: $0.completedDate) })
    }

    func isCompleted(habitId: String, on date: Date) async throws -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        return try await database.dbQueue.read { db in
            try HabitCompletion
                .filter(Column("habitId") == habitId)
                .filter(Column("completedDate") == normalizedDate)
                .fetchCount(db) > 0
        }
    }

    func fetchTodayCompletedHabitIds() async throws -> Set<String> {
        let today = Calendar.current.startOfDay(for: Date())
        return try await database.dbQueue.read { db in
            let completions = try HabitCompletion
                .filter(Column("completedDate") == today)
                .fetchAll(db)
            return Set(completions.map(\.habitId))
        }
    }

    func toggleCompletion(habitId: String, on date: Date) async throws -> Bool {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let isCurrentlyCompleted = try await isCompleted(habitId: habitId, on: normalizedDate)

        if isCurrentlyCompleted {
            try await deleteCompletion(habitId: habitId, date: normalizedDate)
            return false
        } else {
            let completion = HabitCompletion(habitId: habitId, completedDate: normalizedDate)
            try await saveCompletion(completion)
            return true
        }
    }

    // MARK: - Observation (Reactive)

    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Habit]>> {
        ValueObservation.tracking { db in
            try Habit
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func observeActive() -> ValueObservation<ValueReducers.Fetch<[Habit]>> {
        ValueObservation.tracking { db in
            try Habit
                .filter(Column("isArchived") == false)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func observeHabit(id: String) -> ValueObservation<ValueReducers.Fetch<Habit?>> {
        ValueObservation.tracking { db in
            try Habit.fetchOne(db, id: id)
        }
    }

    func observeCompletions(habitId: String) -> ValueObservation<ValueReducers.Fetch<[HabitCompletion]>> {
        ValueObservation.tracking { db in
            try HabitCompletion
                .filter(Column("habitId") == habitId)
                .order(Column("completedDate").desc)
                .fetchAll(db)
        }
    }

    func observeTodayCompletions() -> ValueObservation<ValueReducers.Fetch<Set<String>>> {
        let today = Calendar.current.startOfDay(for: Date())
        return ValueObservation.tracking { db in
            let completions = try HabitCompletion
                .filter(Column("completedDate") == today)
                .fetchAll(db)
            return Set(completions.map(\.habitId))
        }
    }

    // MARK: - Streak Calculations

    func calculateStreakInfo(for habit: Habit) async throws -> HabitStreakInfo {
        let completions = try await fetchCompletions(habitId: habit.id)
        let completionDates = Set(completions.map {
            Calendar.current.startOfDay(for: $0.completedDate)
        })

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate current streak
        let currentStreak = calculateCurrentStreak(
            habit: habit,
            completionDates: completionDates,
            from: today,
            calendar: calendar
        )

        // Calculate longest streak
        let longestStreak = calculateLongestStreak(
            habit: habit,
            completionDates: completionDates,
            calendar: calendar
        )

        // Calculate 30-day completion rate
        let completionRate = calculateCompletionRate(
            habit: habit,
            completionDates: completionDates,
            days: 30,
            calendar: calendar
        )

        // Last completed date
        let lastCompletedDate = completionDates.max()

        return HabitStreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalCompletions: completions.count,
            completionRate: completionRate,
            lastCompletedDate: lastCompletedDate
        )
    }

    private func calculateCurrentStreak(
        habit: Habit,
        completionDates: Set<Date>,
        from startDate: Date,
        calendar: Calendar
    ) -> Int {
        var streak = 0
        var checkDate = startDate

        // If today is a due day and not completed yet, start checking from yesterday
        if habit.isDueOn(checkDate) && !completionDates.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // Walk backwards through due days
        for _ in 0..<365 {
            if habit.isDueOn(checkDate) {
                if completionDates.contains(checkDate) {
                    streak += 1
                } else {
                    break
                }
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }

    private func calculateLongestStreak(
        habit: Habit,
        completionDates: Set<Date>,
        calendar: Calendar
    ) -> Int {
        guard !completionDates.isEmpty else { return 0 }

        let sortedDates = completionDates.sorted()
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else { return 0 }

        var longestStreak = 0
        var currentStreak = 0
        var checkDate = firstDate

        while checkDate <= lastDate {
            if habit.isDueOn(checkDate) {
                if completionDates.contains(checkDate) {
                    currentStreak += 1
                    longestStreak = max(longestStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
                break
            }
            checkDate = nextDay
        }

        return longestStreak
    }

    private func calculateCompletionRate(
        habit: Habit,
        completionDates: Set<Date>,
        days: Int,
        calendar: Calendar
    ) -> Double {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return 0
        }

        var dueDays = 0
        var completedDays = 0
        var checkDate = startDate

        while checkDate <= today {
            if habit.isDueOn(checkDate) {
                dueDays += 1
                if completionDates.contains(checkDate) {
                    completedDays += 1
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate) else {
                break
            }
            checkDate = nextDay
        }

        return dueDays > 0 ? Double(completedDays) / Double(dueDays) : 0
    }

    // MARK: - Statistics

    func activeCount() async throws -> Int {
        try await database.dbQueue.read { db in
            try Habit
                .filter(Column("isArchived") == false)
                .fetchCount(db)
        }
    }

    func todayDueCount() async throws -> Int {
        let habits = try await fetchActive()
        let today = Date()
        return habits.filter { $0.isDueOn(today) }.count
    }

    func todayCompletedCount() async throws -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let habits = try await fetchActive()
        let completedIds = try await fetchTodayCompletedHabitIds()

        return habits.filter { habit in
            habit.isDueOn(today) && completedIds.contains(habit.id)
        }.count
    }
}
