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
    @Published var eventsByDate: [Date: [CalendarEvent]] = [:]
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
    private let sampleEvents: [CalendarEvent]
    private var monthCancellable: AnyCancellable?
    private var selectedDateCancellable: AnyCancellable?

    // MARK: - Init

    init(taskRepository: TaskRepository = TaskRepository()) {
        self.taskRepository = taskRepository
        self.selectedDate = Calendar.current.startOfDay(for: Date())
        self.sampleEvents = SampleCalendarEventProvider.generate()
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

    func createTask(title: String, on date: Date? = nil) async {
        let normalDate = date.map { Calendar.current.startOfDay(for: $0) } ?? selectedDate
        let task = Task(
            title: title,
            status: .next,
            dueDate: normalDate
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

        refreshEvents()

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

    private func refreshEvents() {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            eventsByDate = [:]
            return
        }

        let filtered = sampleEvents.filter { interval.contains($0.startDate) }
        eventsByDate = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startDate) }
    }
}

// MARK: - Sample Events

private enum SampleCalendarEventProvider {
    static func generate() -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func makeEvent(
            dayOffset: Int,
            hour: Int,
            minute: Int,
            durationMinutes: Int,
            title: String,
            calendarType: CalendarEvent.CalendarType,
            location: String? = nil,
            notes: String? = nil
        ) -> CalendarEvent {
            let startBase = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startBase)!
            let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate)!
            return CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                calendarType: calendarType,
                location: location,
                notes: notes
            )
        }

        return [
            makeEvent(dayOffset: 0, hour: 9, minute: 30, durationMinutes: 45, title: "Daily Team Sync", calendarType: .work, location: "Zoom"),
            makeEvent(dayOffset: 0, hour: 13, minute: 0, durationMinutes: 60, title: "Product Review", calendarType: .work, location: "War Room"),
            makeEvent(dayOffset: 1, hour: 11, minute: 0, durationMinutes: 30, title: "1:1 with James", calendarType: .work, location: "Cafe downstairs"),
            makeEvent(dayOffset: 1, hour: 17, minute: 30, durationMinutes: 90, title: "Twelfth Night Rehearsal", calendarType: .personal, location: "Downtown Theater"),
            makeEvent(dayOffset: 2, hour: 10, minute: 0, durationMinutes: 120, title: "Deep Work Block", calendarType: .focus, notes: "Ship explore concept draft"),
            makeEvent(dayOffset: 3, hour: 8, minute: 0, durationMinutes: 60, title: "Studio Yoga", calendarType: .personal, location: "Flow Studio"),
            makeEvent(dayOffset: 4, hour: 15, minute: 0, durationMinutes: 45, title: "Client Handoff", calendarType: .work, location: "Meet"),
            makeEvent(dayOffset: 6, hour: 12, minute: 0, durationMinutes: 30, title: "Daily Team Sync", calendarType: .work),
            makeEvent(dayOffset: 7, hour: 19, minute: 0, durationMinutes: 120, title: "Birthday Dinner", calendarType: .personal, location: "Kin Khao"),
            makeEvent(dayOffset: 10, hour: 10, minute: 30, durationMinutes: 60, title: "Roadmap Review", calendarType: .work),
            makeEvent(dayOffset: 12, hour: 9, minute: 0, durationMinutes: 30, title: "Coffee with Amir", calendarType: .personal, location: "Four Barrel")
        ]
    }
}
