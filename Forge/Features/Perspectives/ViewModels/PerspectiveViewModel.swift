import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class PerspectiveListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var perspectives: [Perspective] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let repository: PerspectiveRepository
    private var cancellable: AnyCancellable?

    // MARK: - Init

    init(repository: PerspectiveRepository = PerspectiveRepository()) {
        self.repository = repository
    }

    // MARK: - Observation

    func startObserving() {
        loadData()
        observePerspectives()
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }

    // MARK: - Actions

    func deletePerspective(_ perspective: Perspective) async {
        do {
            try await repository.delete(perspective)
        } catch {
            self.error = error
        }
    }

    func reorderPerspectives(from source: IndexSet, to destination: Int) {
        perspectives.move(fromOffsets: source, toOffset: destination)

        let updates = perspectives.enumerated().map { ($0.element.id, $0.offset) }
        AsyncTask {
            try? await repository.updateSortOrder(perspectives: updates)
        }
    }

    // MARK: - Private

    private func loadData() {
        isLoading = true
        AsyncTask {
            do {
                // Ensure default perspectives exist
                try await repository.ensureDefaultPerspectives()
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func observePerspectives() {
        cancellable = repository.observeAll()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] perspectives in
                    self?.perspectives = perspectives
                }
            )
    }
}

// MARK: - Perspective Detail ViewModel

@MainActor
final class PerspectiveDetailViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var perspective: Perspective?
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let perspectiveId: String
    private let repository: PerspectiveRepository
    private let taskRepository: TaskRepository
    private var perspectiveCancellable: AnyCancellable?

    // MARK: - Init

    init(perspectiveId: String,
         repository: PerspectiveRepository = PerspectiveRepository(),
         taskRepository: TaskRepository = TaskRepository()) {
        self.perspectiveId = perspectiveId
        self.repository = repository
        self.taskRepository = taskRepository
    }

    // MARK: - Observation

    func startObserving() {
        observePerspective()
    }

    func stopObserving() {
        perspectiveCancellable?.cancel()
        perspectiveCancellable = nil
    }

    // MARK: - Actions

    func completeTask(_ task: Task) async {
        do {
            try await taskRepository.completeTask(task)
            loadTasks()
        } catch {
            self.error = error
        }
    }

    func uncompleteTask(_ task: Task) async {
        do {
            try await taskRepository.uncompleteTask(task)
            loadTasks()
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func observePerspective() {
        perspectiveCancellable = repository.observePerspective(id: perspectiveId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] perspective in
                    self?.perspective = perspective
                    self?.loadTasks()
                }
            )
    }

    private func loadTasks() {
        guard let perspective = perspective else { return }

        isLoading = true
        AsyncTask {
            do {
                let tasks = try await repository.fetchTasks(for: perspective)
                self.tasks = tasks
                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

// MARK: - Perspective Editor ViewModel

@MainActor
final class PerspectiveEditorViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var title: String = ""
    @Published var icon: String = "line.3.horizontal.decrease.circle"
    @Published var color: String = ""

    // Filter config
    @Published var selectedStatuses: Set<TaskStatus> = []
    @Published var selectedPriorities: Set<Priority> = []
    @Published var isFlagged: Bool? = nil
    @Published var dueDateRange: DateRangeFilter? = nil
    @Published var showCompleted: Bool = false
    @Published var sortBy: SortOption = .dueDate
    @Published var sortAscending: Bool = true

    @Published var isSaving = false
    @Published var error: Error?

    // MARK: - Properties

    var isEditing: Bool { existingPerspective != nil }
    private var existingPerspective: Perspective?

    // MARK: - Dependencies

    private let repository: PerspectiveRepository

    // MARK: - Init

    init(perspective: Perspective? = nil, repository: PerspectiveRepository = PerspectiveRepository()) {
        self.existingPerspective = perspective
        self.repository = repository

        if let perspective = perspective {
            loadFromPerspective(perspective)
        }
    }

    // MARK: - Actions

    func save() async -> Bool {
        guard !title.isEmpty else {
            error = NSError(domain: "Forge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Title is required"])
            return false
        }

        isSaving = true

        let config = FilterConfig(
            statuses: selectedStatuses.isEmpty ? nil : Array(selectedStatuses),
            priorities: selectedPriorities.isEmpty ? nil : Array(selectedPriorities),
            isFlagged: isFlagged,
            dueDateRange: dueDateRange,
            showCompleted: showCompleted,
            sortBy: sortBy,
            sortAscending: sortAscending
        )

        var perspective = existingPerspective ?? Perspective(title: title)
        perspective.title = title
        perspective.icon = icon
        perspective.color = color.isEmpty ? nil : color
        perspective.filterConfig = config

        do {
            try await repository.save(perspective)
            isSaving = false
            return true
        } catch {
            self.error = error
            isSaving = false
            return false
        }
    }

    // MARK: - Private

    private func loadFromPerspective(_ perspective: Perspective) {
        title = perspective.title
        icon = perspective.icon
        color = perspective.color ?? ""

        let config = perspective.filterConfig
        selectedStatuses = Set(config.statuses ?? [])
        selectedPriorities = Set(config.priorities ?? [])
        isFlagged = config.isFlagged
        dueDateRange = config.dueDateRange
        showCompleted = config.showCompleted
        sortBy = config.sortBy
        sortAscending = config.sortAscending
    }
}
