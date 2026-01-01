import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel: TaskViewModel
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle = ""
    @State private var isAddingTask = false
    @FocusState private var isNewTaskFocused: Bool

    init(filter: TaskViewModel.Filter) {
        _viewModel = StateObject(wrappedValue: TaskViewModel(filter: filter))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Task list
            if viewModel.tasks.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                taskList
            }

            // Quick add bar
            if viewModel.filter != .completed {
                quickAddBar
            }
        }
        .navigationTitle(viewModel.filter.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { isAddingTask = true }) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)

                Menu {
                    Button("Sort by Due Date") { }
                    Button("Sort by Priority") { }
                    Button("Sort by Created") { }
                    Divider()
                    Button("Show Completed") { }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        List(selection: $appState.selectedTaskId) {
            ForEach(viewModel.tasks) { task in
                TaskRowView(
                    task: task,
                    onToggleComplete: {
                        Task { await viewModel.toggleComplete(task) }
                    },
                    onToggleFlag: {
                        Task { await viewModel.toggleFlag(task) }
                    }
                )
                .tag(task.id)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .onDelete(perform: deleteTasks)
            .onMove(perform: moveTasks)
        }
        .listStyle(.inset)
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title2)

            TextField("Add task...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($isNewTaskFocused)
                .onSubmit {
                    addTask()
                }

            if !newTaskTitle.isEmpty {
                Button(action: addTask) {
                    Text("Add")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.filter.icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(viewModel.filter.emptyMessage)
                .font(.headline)
                .foregroundColor(.secondary)

            if viewModel.filter != .completed {
                Button(action: { isNewTaskFocused = true }) {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let projectId: String? = {
            if case .project(let id) = viewModel.filter {
                return id
            }
            return nil
        }()

        Task {
            await viewModel.createTask(title: newTaskTitle, projectId: projectId)
            newTaskTitle = ""
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = viewModel.tasks[index]
            Task {
                await viewModel.deleteTask(task)
            }
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var tasks = viewModel.tasks
        tasks.move(fromOffsets: source, toOffset: destination)
        Task {
            await viewModel.reorderTasks(tasks)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskListView(filter: .inbox)
        .environmentObject(AppState())
}
