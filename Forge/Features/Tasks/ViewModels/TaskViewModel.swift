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
    @Published var subtaskCounts: [String: (total: Int, completed: Int)] = [:]
    @Published var expandedTaskIds: Set<String> = []
    @Published var subtasks: [String: [Task]] = [:]  // parentId -> subtasks

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
    private var subtaskCountsCancellable: AnyCancellable?
    private var subtaskCancellables: [String: AnyCancellable] = [:]

    // MARK: - Init

    init(filter: Filter, repository: TaskRepository = TaskRepository()) {
        self.filter = filter
        self.repository = repository
    }

    // MARK: - Observation

    func startObserving() {
        isLoading = true
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

        // Also observe subtask counts
        startObservingSubtaskCounts()
    }

    private func startObservingSubtaskCounts() {
        subtaskCountsCancellable = repository.observeSubtaskCounts()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] counts in
                    self?.subtaskCounts = counts
                }
            )
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
        subtaskCountsCancellable?.cancel()
        subtaskCountsCancellable = nil
        subtaskCancellables.values.forEach { $0.cancel() }
        subtaskCancellables.removeAll()
    }

    // MARK: - Expansion

    func toggleExpanded(_ taskId: String) {
        if expandedTaskIds.contains(taskId) {
            expandedTaskIds.remove(taskId)
            subtaskCancellables[taskId]?.cancel()
            subtaskCancellables.removeValue(forKey: taskId)
        } else {
            expandedTaskIds.insert(taskId)
            startObservingSubtasks(for: taskId)
        }
    }

    private func startObservingSubtasks(for parentId: String) {
        subtaskCancellables[parentId] = repository.observeSubtasks(parentId: parentId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tasks in
                    self?.subtasks[parentId] = tasks
                }
            )
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

    func setStatus(_ task: Task, status: TaskStatus) async {
        var updated = task
        updated.status = status
        if status == .completed {
            updated.completedAt = Date()
        } else {
            updated.completedAt = nil
        }
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
    @Published var projects: [Project] = []
    @Published var allTags: [Tag] = []
    @Published var taskTags: [Tag] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let taskId: String
    private let repository: TaskRepository
    private let projectRepository: ProjectRepository
    private let tagRepository: TagRepository
    private var cancellables = Set<AnyCancellable>()

    init(taskId: String, repository: TaskRepository = TaskRepository(), projectRepository: ProjectRepository = ProjectRepository(), tagRepository: TagRepository = TagRepository()) {
        self.taskId = taskId
        self.repository = repository
        self.projectRepository = projectRepository
        self.tagRepository = tagRepository
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

        // Observe subtasks
        repository.observeSubtasks(parentId: taskId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tasks in
                    self?.subtasks = tasks
                }
            )
            .store(in: &cancellables)

        // Fetch projects and tags
        AsyncTask {
            await fetchProjects()
            await fetchTags()
        }

        // Observe task tags
        tagRepository.observeTagsForTask(taskId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] tags in
                    self?.taskTags = tags
                }
            )
            .store(in: &cancellables)
    }

    private func fetchProjects() async {
        do {
            projects = try await projectRepository.fetchActive()
        } catch {
            // Ignore project fetch errors
        }
    }

    private func fetchTags() async {
        do {
            allTags = try await tagRepository.fetchAll()
        } catch {
            // Ignore tag fetch errors
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
    }

    func deleteSubtask(_ subtask: Task) async {
        do {
            try await repository.delete(subtask)
        } catch {
            self.error = error
        }
    }

    // MARK: - Tag Operations

    func addTag(_ tag: Tag) async {
        do {
            try await tagRepository.addTagToTask(tagId: tag.id, taskId: taskId)
        } catch {
            self.error = error
        }
    }

    func removeTag(_ tag: Tag) async {
        do {
            try await tagRepository.removeTagFromTask(tagId: tag.id, taskId: taskId)
        } catch {
            self.error = error
        }
    }

    func createAndAddTag(name: String, type: TagType) async {
        let tag = Tag(name: name, tagType: type)
        do {
            try await tagRepository.save(tag)
            try await tagRepository.addTagToTask(tagId: tag.id, taskId: taskId)
            await fetchTags()
        } catch {
            self.error = error
        }
    }

}
