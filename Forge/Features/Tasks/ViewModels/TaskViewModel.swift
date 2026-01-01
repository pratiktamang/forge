import SwiftUI
import Combine
import GRDB

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

@MainActor
final class TaskViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var tasks: [Task] = []
    @Published var selectedTask: Task?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var inboxCount: Int = 0

    // MARK: - Filter

    enum Filter: Equatable {
        case inbox
        case today
        case upcoming
        case flagged
        case project(String)
        case completed

        var title: String {
            switch self {
            case .inbox: return "Inbox"
            case .today: return "Today"
            case .upcoming: return "Upcoming"
            case .flagged: return "Flagged"
            case .project: return "Project"
            case .completed: return "Completed"
            }
        }

        var icon: String {
            switch self {
            case .inbox: return "tray"
            case .today: return "star"
            case .upcoming: return "calendar"
            case .flagged: return "flag"
            case .project: return "folder"
            case .completed: return "checkmark.circle"
            }
        }

        var emptyMessage: String {
            switch self {
            case .inbox: return "Your inbox is empty"
            case .today: return "Nothing due today"
            case .upcoming: return "No upcoming tasks"
            case .flagged: return "No flagged tasks"
            case .project: return "No tasks in this project"
            case .completed: return "No completed tasks"
            }
        }
    }

    let filter: Filter

    // MARK: - Dependencies

    private let repository: TaskRepository
    private var cancellable: AnyCancellable?

    // MARK: - Init

    init(filter: Filter, repository: TaskRepository = TaskRepository()) {
        self.filter = filter
        self.repository = repository
    }

    // MARK: - Observation

    func startObserving() {
        switch filter {
        case .inbox:
            startObserving(repository.observeInbox())
        case .today:
            startObserving(repository.observeToday())
        case .upcoming:
            startObserving(repository.observeUpcoming())
        case .flagged:
            startObserving(repository.observeFlagged())
        case .project(let projectId):
            startObserving(repository.observeByProject(projectId))
        case .completed:
            // For completed, we'll fetch once instead of observing
            AsyncTask { await fetchCompleted() }
            return
        }
    }

    private func startObserving<T: ValueReducer>(_ observation: ValueObservation<T>) where T.Value == [Task] {
        cancellable = observation
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] tasks in
                    self?.tasks = tasks
                    self?.isLoading = false
                }
            )
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }

    // MARK: - Actions

    func createTask(title: String, notes: String? = nil, projectId: String? = nil, dueDate: Date? = nil) async {
        let task = Task(
            title: title,
            notes: notes,
            projectId: projectId,
            status: projectId != nil ? .next : .inbox,
            dueDate: dueDate
        )

        do {
            try await repository.save(task)
        } catch {
            self.error = error
        }
    }

    func completeTask(_ task: Task) async {
        do {
            try await repository.completeTask(task)
        } catch {
            self.error = error
        }
    }

    func uncompleteTask(_ task: Task) async {
        do {
            try await repository.uncompleteTask(task)
        } catch {
            self.error = error
        }
    }

    func toggleComplete(_ task: Task) async {
        if task.status == .completed {
            await uncompleteTask(task)
        } else {
            await completeTask(task)
        }
    }

    func deleteTask(_ task: Task) async {
        do {
            try await repository.delete(task)
            if selectedTask?.id == task.id {
                selectedTask = nil
            }
        } catch {
            self.error = error
        }
    }

    func updateTask(_ task: Task) async {
        do {
            try await repository.save(task)
        } catch {
            self.error = error
        }
    }

    func toggleFlag(_ task: Task) async {
        var updated = task
        updated.isFlagged.toggle()
        await updateTask(updated)
    }

    func moveToProject(_ task: Task, projectId: String?) async {
        do {
            try await repository.moveToProject(task, projectId: projectId)
        } catch {
            self.error = error
        }
    }

    func reorderTasks(_ tasks: [Task]) async {
        let updates = tasks.enumerated().map { (index, task) in
            (id: task.id, sortOrder: index)
        }

        do {
            try await repository.updateSortOrder(tasks: updates)
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func fetchCompleted() async {
        isLoading = true
        do {
            tasks = try await repository.fetchCompleted()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func refreshInboxCount() async {
        do {
            inboxCount = try await repository.inboxCount()
        } catch {
            // Ignore count errors
        }
    }
}

// MARK: - Task Detail ViewModel

@MainActor
final class TaskDetailViewModel: ObservableObject {
    @Published var task: Task?
    @Published var subtasks: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let taskId: String
    private let repository: TaskRepository
    private var cancellables = Set<AnyCancellable>()

    init(taskId: String, repository: TaskRepository = TaskRepository()) {
        self.taskId = taskId
        self.repository = repository
    }

    func startObserving() {
        // Observe main task
        repository.observeTask(id: taskId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] task in
                    self?.task = task
                }
            )
            .store(in: &cancellables)

        // Fetch subtasks
        AsyncTask {
            await fetchSubtasks()
        }
    }

    func stopObserving() {
        cancellables.removeAll()
    }

    func save() async {
        guard var task = task else { return }
        task.updatedAt = Date()

        do {
            try await repository.save(task)
        } catch {
            self.error = error
        }
    }

    func addSubtask(title: String) async {
        let subtask = Task(
            title: title,
            parentTaskId: taskId,
            status: .next
        )

        do {
            try await repository.save(subtask)
            await fetchSubtasks()
        } catch {
            self.error = error
        }
    }

    func toggleSubtask(_ subtask: Task) async {
        if subtask.status == .completed {
            try? await repository.uncompleteTask(subtask)
        } else {
            try? await repository.completeTask(subtask)
        }
        await fetchSubtasks()
    }

    private func fetchSubtasks() async {
        do {
            subtasks = try await repository.fetchSubtasks(parentId: taskId)
        } catch {
            self.error = error
        }
    }
}
