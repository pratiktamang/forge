import SwiftUI
import Combine
import GRDB

@MainActor
final class BoardViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var board: Board?
    @Published var columns: [BoardColumn] = []
    @Published var tasksByColumn: [String: [Task]] = [:]
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let boardId: String
    private let boardRepository: BoardRepository
    private let taskRepository: TaskRepository
    private var cancellables = Set<AnyCancellable>()
    private var columnTaskCancellables: [String: AnyCancellable] = [:]

    // MARK: - Init

    init(boardId: String, boardRepository: BoardRepository = BoardRepository(), taskRepository: TaskRepository = TaskRepository()) {
        self.boardId = boardId
        self.boardRepository = boardRepository
        self.taskRepository = taskRepository
    }

    // MARK: - Observation

    func startObserving() {
        isLoading = true

        // Observe board
        boardRepository.observeBoard(id: boardId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] board in
                    self?.board = board
                }
            )
            .store(in: &cancellables)

        // Observe columns
        boardRepository.observeColumns(boardId: boardId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] columns in
                    self?.columns = columns
                    self?.isLoading = false
                    // Observe tasks for each column
                    self?.observeTasksForColumns(columns)
                }
            )
            .store(in: &cancellables)
    }

    private func observeTasksForColumns(_ columns: [BoardColumn]) {
        let columnIds = Set(columns.map(\.id))

        // Cancel observations for removed columns
        for (columnId, cancellable) in columnTaskCancellables {
            if !columnIds.contains(columnId) {
                cancellable.cancel()
                columnTaskCancellables.removeValue(forKey: columnId)
                tasksByColumn.removeValue(forKey: columnId)
            }
        }

        for column in columns {
            guard columnTaskCancellables[column.id] == nil else { continue }

            let cancellable = taskRepository.observeByBoardColumn(column.id)
                .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] tasks in
                        self?.tasksByColumn[column.id] = tasks
                    }
                )

            columnTaskCancellables[column.id] = cancellable
        }
    }

    func stopObserving() {
        cancellables.removeAll()
        columnTaskCancellables.values.forEach { $0.cancel() }
        columnTaskCancellables.removeAll()
    }

    // MARK: - Column Actions

    func addColumn(title: String, color: String? = nil) async {
        let sortOrder = columns.count
        let column = BoardColumn(
            boardId: boardId,
            title: title,
            color: color,
            sortOrder: sortOrder
        )

        do {
            try await boardRepository.saveColumn(column)
        } catch {
            self.error = error
        }
    }

    func updateColumn(_ column: BoardColumn) async {
        do {
            try await boardRepository.saveColumn(column)
        } catch {
            self.error = error
        }
    }

    func deleteColumn(_ column: BoardColumn) async {
        do {
            try await boardRepository.deleteColumn(column)
        } catch {
            self.error = error
        }
    }

    func reorderColumns(_ reorderedColumns: [BoardColumn]) async {
        let updates = reorderedColumns.enumerated().map { (index, column) in
            (id: column.id, sortOrder: index)
        }

        do {
            try await boardRepository.updateColumnOrder(columns: updates)
        } catch {
            self.error = error
        }
    }

    // MARK: - Task Actions

    func moveTask(_ taskId: String?, to column: BoardColumn) async {
        guard let taskId = taskId else { return }

        do {
            guard var task = try await taskRepository.fetch(id: taskId) else { return }

            // Update column
            task.boardColumnId = column.id

            // Update status based on column mapping
            if let mappedStatus = column.mappedStatus {
                task.status = mappedStatus
                if mappedStatus == .completed {
                    task.completedAt = Date()
                } else {
                    task.completedAt = nil
                }
            }

            try await taskRepository.save(task)
        } catch {
            self.error = error
        }
    }

    func addTask(title: String, to column: BoardColumn) async {
        let taskCount = tasksByColumn[column.id]?.count ?? 0

        var task = Task(
            title: title,
            boardColumnId: column.id,
            status: column.mappedStatus ?? .next,
            sortOrder: taskCount
        )

        // If column maps to completed, mark the task completed
        if column.mappedStatus == .completed {
            task.completedAt = Date()
        }

        // Get projectId from board
        if let projectId = board?.projectId {
            task.projectId = projectId
        }

        do {
            try await taskRepository.save(task)
        } catch {
            self.error = error
        }
    }

    func reorderTasks(in columnId: String, tasks: [Task]) async {
        let updates = tasks.enumerated().map { (index, task) in
            (id: task.id, sortOrder: index)
        }

        do {
            try await taskRepository.updateSortOrder(tasks: updates)
        } catch {
            self.error = error
        }
    }

    func tasks(for column: BoardColumn) -> [Task] {
        tasksByColumn[column.id] ?? []
    }

    func taskCount(for column: BoardColumn) -> Int {
        tasksByColumn[column.id]?.count ?? 0
    }

    func isOverWipLimit(column: BoardColumn) -> Bool {
        guard let wipLimit = column.wipLimit else { return false }
        return taskCount(for: column) > wipLimit
    }
}

// MARK: - Drag Item

struct TaskDragItem: Codable, Transferable {
    let taskId: String
    let sourceColumnId: String?

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: TaskDragItem.self, contentType: .json)
    }
}

struct ColumnDragItem: Codable, Transferable {
    let columnId: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: ColumnDragItem.self, contentType: .json)
    }
}
