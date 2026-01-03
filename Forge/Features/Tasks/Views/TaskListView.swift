import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskListView: View {
    @StateObject private var viewModel: TaskViewModel
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle = ""
    @FocusState private var isNewTaskFocused: Bool
    @FocusState private var isListFocused: Bool

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
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isNewTaskFocused = true }) {
                    Image(systemName: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(Array(viewModel.tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRowView(
                            task: task,
                            isSelected: appState.selectedTaskId == task.id,
                            onToggleComplete: {
                                AsyncTask { await viewModel.toggleComplete(task) }
                            },
                            onToggleFlag: {
                                AsyncTask { await viewModel.toggleFlag(task) }
                            },
                            onSetPriority: { priority in
                                AsyncTask { await viewModel.setPriority(task, priority: priority) }
                            },
                            onSetStatus: { status in
                                AsyncTask { await viewModel.setStatus(task, status: status) }
                            },
                            onDelete: {
                                AsyncTask { await viewModel.deleteTask(task) }
                            },
                            onMoveUp: index > 0 ? { moveTask(task, by: -1) } : nil,
                            onMoveDown: index < viewModel.tasks.count - 1 ? { moveTask(task, by: 1) } : nil,
                            canMoveUp: index > 0,
                            canMoveDown: index < viewModel.tasks.count - 1
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .id(task.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                appState.selectedTaskId = task.id
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .background(AppTheme.contentBackground)
            .animation(.easeInOut(duration: 0.2), value: viewModel.tasks)
            .onChange(of: appState.selectedTaskId) { _, newValue in
                if let newValue {
                    proxy.scrollTo(newValue, anchor: .center)
                    isListFocused = true
                }
            }
            .focusable()
            .focused($isListFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) {
                selectPreviousTask()
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectNextTask()
                return .handled
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func selectPreviousTask() {
        guard !viewModel.tasks.isEmpty else { return }

        if let currentId = appState.selectedTaskId,
           let currentIndex = viewModel.tasks.firstIndex(where: { $0.id == currentId }),
           currentIndex > 0 {
            withAnimation(.easeInOut(duration: 0.16)) {
                appState.selectedTaskId = viewModel.tasks[currentIndex - 1].id
            }
        } else if appState.selectedTaskId == nil {
            // Select first task if none selected
            withAnimation(.easeInOut(duration: 0.16)) {
                appState.selectedTaskId = viewModel.tasks.first?.id
            }
        }
    }

    private func selectNextTask() {
        guard !viewModel.tasks.isEmpty else { return }

        if let currentId = appState.selectedTaskId,
           let currentIndex = viewModel.tasks.firstIndex(where: { $0.id == currentId }),
           currentIndex < viewModel.tasks.count - 1 {
            withAnimation(.easeInOut(duration: 0.16)) {
                appState.selectedTaskId = viewModel.tasks[currentIndex + 1].id
            }
        } else if appState.selectedTaskId == nil {
            // Select first task if none selected
            withAnimation(.easeInOut(duration: 0.16)) {
                appState.selectedTaskId = viewModel.tasks.first?.id
            }
        }
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.title2)

            TextField("Add task...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
                .focused($isNewTaskFocused)
                .onSubmit { addTask() }

            if !newTaskTitle.isEmpty {
                Button(action: addTask) {
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.pillPurple)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.quickAddBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: viewModel.filter.icon)
                .font(.system(size: 56))
                .foregroundStyle(.linearGradient(
                    colors: emptyStateGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title2.weight(.semibold))

                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            if viewModel.filter != .completed {
                Button(action: { isNewTaskFocused = true }) {
                    Label("Add Task", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.emptyStateBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.contentBackground)
    }

    private var emptyStateTitle: String {
        switch viewModel.filter {
        case .inbox: return "Inbox Zero!"
        case .today: return "All Clear for Today"
        case .upcoming: return "Nothing Scheduled"
        case .flagged: return "No Flagged Tasks"
        case .project: return "Empty Project"
        case .completed: return "No Completed Tasks"
        }
    }

    private var emptyStateSubtitle: String {
        switch viewModel.filter {
        case .inbox: return "Capture new tasks here. They'll wait until you're ready to organize them."
        case .today: return "No tasks due today. Add one or check your upcoming tasks."
        case .upcoming: return "No tasks with due dates. Set a due date on tasks to see them here."
        case .flagged: return "Flag important tasks to see them here for quick access."
        case .project: return "This project has no tasks yet. Add your first task to get started."
        case .completed: return "Completed tasks will appear here."
        }
    }

    private var emptyStateGradientColors: [Color] {
        switch viewModel.filter {
        case .inbox: return [.blue, .cyan]
        case .today: return [.orange, .yellow]
        case .upcoming: return [.purple, .pink]
        case .flagged: return [.orange, .red]
        case .project: return [.green, .teal]
        case .completed: return [.green, .mint]
        }
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

        AsyncTask {
            await viewModel.createTask(title: newTaskTitle, projectId: projectId)
            newTaskTitle = ""
        }
    }

    private func moveTask(_ task: Task, by offset: Int) {
        guard let index = viewModel.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let destination = max(0, min(viewModel.tasks.count - 1, index + offset))
        guard destination != index else { return }

        var reordered = viewModel.tasks
        reordered.move(fromOffsets: IndexSet(integer: index), toOffset: destination > index ? destination + 1 : destination)

        AsyncTask {
            await viewModel.reorderTasks(reordered)
        }
    }

}

// MARK: - Preview

#Preview {
    TaskListView(filter: .inbox)
        .environmentObject(AppState())
}
