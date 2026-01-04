import SwiftUI
import Combine
import GRDB

@MainActor
final class CalendarDayDetailViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var events: [CalendarEvent] = []
    @Published var error: Error?

    let date: Date

    private let taskRepository: TaskRepository
    private let eventProvider: CalendarEventProviding
    private var tasksCancellable: AnyCancellable?

    init(
        date: Date,
        taskRepository: TaskRepository = TaskRepository(),
        eventProvider: CalendarEventProviding = SampleCalendarEventProvider()
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.taskRepository = taskRepository
        self.eventProvider = eventProvider
        observeTasks()
        loadEvents()
    }

    deinit {
        tasksCancellable?.cancel()
    }

    func createTask(title: String) async {
        let task = Task(
            title: title,
            status: .next,
            dueDate: date
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

    private func observeTasks() {
        tasksCancellable?.cancel()
        tasksCancellable = taskRepository.observeByDate(date)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tasks in
                    self?.tasks = tasks
                }
            )
    }

    private func loadEvents() {
        events = eventProvider.events(on: date)
    }
}
