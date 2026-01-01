import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

// MARK: - Habit List ViewModel

@MainActor
final class HabitListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var habits: [Habit] = []
    @Published var todayCompletions: Set<String> = []
    @Published var streakInfo: [String: HabitStreakInfo] = [:]
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let repository: HabitRepository
    private var habitsCancellable: AnyCancellable?
    private var completionsCancellable: AnyCancellable?

    // MARK: - Init

    init(repository: HabitRepository = HabitRepository()) {
        self.repository = repository
    }

    // MARK: - Computed Properties

    var habitsDueToday: [Habit] {
        let today = Date()
        return habits.filter { $0.isDueOn(today) && !$0.isArchived }
    }

    var habitsNotDueToday: [Habit] {
        let today = Date()
        return habits.filter { !$0.isDueOn(today) && !$0.isArchived }
    }

    var todayCompletionCount: Int {
        habitsDueToday.filter { todayCompletions.contains($0.id) }.count
    }

    var todayProgress: Double {
        let dueCount = habitsDueToday.count
        guard dueCount > 0 else { return 1.0 }
        return Double(todayCompletionCount) / Double(dueCount)
    }

    // MARK: - Observation

    func startObserving() {
        isLoading = true

        // Observe active habits
        habitsCancellable = repository.observeActive()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] habits in
                    self?.habits = habits
                    self?.isLoading = false
                    AsyncTask { await self?.refreshStreakInfo() }
                }
            )

        // Observe today's completions
        completionsCancellable = repository.observeTodayCompletions()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completedIds in
                    self?.todayCompletions = completedIds
                }
            )
    }

    func stopObserving() {
        habitsCancellable?.cancel()
        habitsCancellable = nil
        completionsCancellable?.cancel()
        completionsCancellable = nil
    }

    // MARK: - Actions

    func createHabit(
        title: String,
        description: String? = nil,
        frequencyType: FrequencyType = .daily,
        frequencyDays: [Int]? = nil,
        timesPerPeriod: Int = 1,
        reminderTime: String? = nil,
        color: String? = nil,
        icon: String? = "checkmark.circle"
    ) async {
        let habit = Habit(
            title: title,
            description: description,
            frequencyType: frequencyType,
            frequencyDays: frequencyDays,
            timesPerPeriod: timesPerPeriod,
            reminderTime: reminderTime,
            color: color,
            icon: icon
        )

        do {
            try await repository.save(habit)
        } catch {
            self.error = error
        }
    }

    func toggleCompletion(habit: Habit, on date: Date = Date()) async {
        do {
            _ = try await repository.toggleCompletion(habitId: habit.id, on: date)
            // Refresh streak info for this habit
            if let info = try? await repository.calculateStreakInfo(for: habit) {
                streakInfo[habit.id] = info
            }
        } catch {
            self.error = error
        }
    }

    func deleteHabit(_ habit: Habit) async {
        do {
            try await repository.delete(habit)
            streakInfo.removeValue(forKey: habit.id)
        } catch {
            self.error = error
        }
    }

    func archiveHabit(_ habit: Habit) async {
        var updated = habit
        updated.isArchived = true
        do {
            try await repository.save(updated)
        } catch {
            self.error = error
        }
    }

    func unarchiveHabit(_ habit: Habit) async {
        var updated = habit
        updated.isArchived = false
        do {
            try await repository.save(updated)
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func refreshStreakInfo() async {
        for habit in habits {
            do {
                let info = try await repository.calculateStreakInfo(for: habit)
                streakInfo[habit.id] = info
            } catch {
                // Ignore individual streak calculation errors
            }
        }
    }
}

// MARK: - Habit Detail ViewModel

@MainActor
final class HabitDetailViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var habit: Habit?
    @Published var completions: [HabitCompletion] = []
    @Published var streakInfo: HabitStreakInfo?
    @Published var completionDates: Set<Date> = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let habitId: String
    private let repository: HabitRepository
    private var habitCancellable: AnyCancellable?
    private var completionsCancellable: AnyCancellable?

    // MARK: - Init

    init(habitId: String, repository: HabitRepository = HabitRepository()) {
        self.habitId = habitId
        self.repository = repository
    }

    // MARK: - Observation

    func startObserving() {
        isLoading = true

        // Observe habit
        habitCancellable = repository.observeHabit(id: habitId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] habit in
                    self?.habit = habit
                    self?.isLoading = false
                    AsyncTask { await self?.refreshStreakInfo() }
                }
            )

        // Observe completions
        completionsCancellable = repository.observeCompletions(habitId: habitId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] completions in
                    self?.completions = completions
                    self?.completionDates = Set(completions.map {
                        Calendar.current.startOfDay(for: $0.completedDate)
                    })
                }
            )
    }

    func stopObserving() {
        habitCancellable?.cancel()
        habitCancellable = nil
        completionsCancellable?.cancel()
        completionsCancellable = nil
    }

    // MARK: - Actions

    func save() async {
        guard var habit = habit else { return }
        habit.updatedAt = Date()

        do {
            try await repository.save(habit)
        } catch {
            self.error = error
        }
    }

    func toggleCompletion(on date: Date) async {
        do {
            _ = try await repository.toggleCompletion(habitId: habitId, on: date)
            await refreshStreakInfo()
        } catch {
            self.error = error
        }
    }

    func delete() async {
        guard let habit = habit else { return }
        do {
            try await repository.delete(habit)
        } catch {
            self.error = error
        }
    }

    func archive() async {
        guard var habit = habit else { return }
        habit.isArchived = true
        do {
            try await repository.save(habit)
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func refreshStreakInfo() async {
        guard let habit = habit else { return }
        do {
            streakInfo = try await repository.calculateStreakInfo(for: habit)
        } catch {
            // Ignore streak calculation errors
        }
    }
}
