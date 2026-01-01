import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class CalendarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var displayedMonth: Date = Date()
    @Published var selectedDate: Date = Date()
    @Published var tasksForMonth: [Task] = []
    @Published var tasksForSelectedDate: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Computed Properties

    var tasksByDate: [Date: [Task]] {
        let calendar = Calendar.current
        var grouped: [Date: [Task]] = [:]
        for task in tasksForMonth {
            if let dueDate = task.dueDate {
                let normalized = calendar.startOfDay(for: dueDate)
                grouped[normalized, default: []].append(task)
            }
        }
        return grouped
    }

    var monthInterval: (start: Date, end: Date) {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return (displayedMonth, displayedMonth)
        }
        return (interval.start, calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end)
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    var selectedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Dependencies

    private let taskRepository: TaskRepository
    private var monthCancellable: AnyCancellable?
    private var selectedDateCancellable: AnyCancellable?

    // MARK: - Init

    init(taskRepository: TaskRepository = TaskRepository()) {
        self.taskRepository = taskRepository
        self.selectedDate = Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Observation

    func startObserving() {
        loadMonth()
        observeSelectedDate()
    }

    func stopObserving() {
        monthCancellable?.cancel()
        monthCancellable = nil
        selectedDateCancellable?.cancel()
        selectedDateCancellable = nil
    }

    // MARK: - Navigation

    func previousMonth() {
        guard let newDate = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = newDate
        loadMonth()
    }

    func nextMonth() {
        guard let newDate = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = newDate
        loadMonth()
    }

    func goToToday() {
        displayedMonth = Date()
        selectedDate = Calendar.current.startOfDay(for: Date())
        loadMonth()
        observeSelectedDate()
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        observeSelectedDate()
    }

    // MARK: - Task Actions

    func createTask(title: String) async {
        let task = Task(
            title: title,
            status: .next,
            dueDate: selectedDate
        )

        do {
            try await taskRepository.save(task)
        } catch {
            self.error = error
        }
    }

    func toggleComplete(_ task: Task) async {
        do {
            if task.status == .completed {
                try await taskRepository.uncompleteTask(task)
            } else {
                try await taskRepository.completeTask(task)
            }
        } catch {
            self.error = error
        }
    }

    func toggleFlag(_ task: Task) async {
        var updated = task
        updated.isFlagged.toggle()
        do {
            try await taskRepository.save(updated)
        } catch {
            self.error = error
        }
    }

    func deleteTask(_ task: Task) async {
        do {
            try await taskRepository.delete(task)
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func loadMonth() {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else { return }

        monthCancellable?.cancel()
        monthCancellable = taskRepository.observeByDateRange(from: monthStart, to: monthEnd)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.tasksForMonth = tasks
                    self?.isLoading = false
                }
            )
    }

    private func observeSelectedDate() {
        selectedDateCancellable?.cancel()
        selectedDateCancellable = taskRepository.observeByDate(selectedDate)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tasks in
                    self?.tasksForSelectedDate = tasks
                }
            )
    }
}
