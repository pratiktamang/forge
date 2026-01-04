import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct CalendarTaskList: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle = ""
    @State private var taskFilter: TaskFilter = .all
    @FocusState private var isAddingTask: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack {
                Text(viewModel.selectedDateFormatted)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Text("\(viewModel.tasksForSelectedDate.count) tasks")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppTheme.cardBorder.opacity(0.8))
                    .frame(height: 1)
            }

            if viewModel.tasksForSelectedDate.isEmpty && !isAddingTask {
                emptyState
            } else {
                taskList
            }

            // Quick add bar
            quickAddBar
        }
        .background(AppTheme.contentBackground)
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: 0) {
            filterControl
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(AppTheme.contentBackground)

            if shouldShowFocusHighlights {
                focusHighlights
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            List(selection: $appState.selectedTaskId) {
                ForEach(filteredTasks) { task in
                    TaskRowView(
                        task: task,
                        isSelected: appState.selectedTaskId == task.id,
                        onToggleComplete: {
                            AsyncTask { await viewModel.toggleComplete(task) }
                        },
                        onToggleFlag: {
                            AsyncTask { await viewModel.toggleFlag(task) }
                        }
                    )
                    .tag(task.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(AppTheme.contentBackground)
                }
                .onDelete { offsets in
                    deleteTasks(in: filteredTasks, at: offsets)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.contentBackground)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.accent)

            Text("No tasks scheduled")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)

            Button(action: { isAddingTask = true }) {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(32)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.emptyStateBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.contentBackground)
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.title2)

            TextField("Add task for \(shortDateString)...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.cardBackground)
                )
                .focused($isAddingTask)
                .onSubmit {
                    addTask()
                }

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

    // MARK: - Helpers

    private var filteredTasks: [Task] {
        switch taskFilter {
        case .all:
            return viewModel.tasksForSelectedDate
        case .focus:
            return viewModel.tasksForSelectedDate.filter { $0.isFlagged || $0.isOverdue }
        case .completed:
            return viewModel.tasksForSelectedDate.filter { $0.status == .completed }
        }
    }

    private var focusTasks: [Task] {
        viewModel.tasksForSelectedDate.filter { $0.isFlagged || $0.isOverdue }
    }

    private var shouldShowFocusHighlights: Bool {
        taskFilter != .completed && !focusTasks.isEmpty
    }

    private var shortDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.selectedDate) {
            return "today"
        } else if calendar.isDateInTomorrow(viewModel.selectedDate) {
            return "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: viewModel.selectedDate)
        }
    }

    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        AsyncTask {
            await viewModel.createTask(title: newTaskTitle)
            newTaskTitle = ""
        }
    }

    private func deleteTasks(in tasks: [Task], at offsets: IndexSet) {
        for index in offsets {
            guard index < tasks.count else { continue }
            let task = tasks[index]
            AsyncTask {
                await viewModel.deleteTask(task)
            }
        }
    }
}

// MARK: - Filter / Highlights

private extension CalendarTaskList {
    private var filterControl: some View {
        HStack(spacing: 10) {
            ForEach(TaskFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        taskFilter = filter
                    }
                }) {
                    Text(filter.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(filter == taskFilter ? AppTheme.selectionBackground.opacity(0.35) : AppTheme.cardBackground.opacity(0.6))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(filter == taskFilter ? AppTheme.selectionBorder.opacity(0.7) : AppTheme.cardBorder.opacity(0.5), lineWidth: 1)
                        )
                        .foregroundColor(filter == taskFilter ? AppTheme.accent : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !filteredTasks.isEmpty {
                Text("\(filteredTasks.count) shown")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
    }

    private var focusHighlights: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(focusTasks.prefix(3)), id: \.id) { task in
                    FocusCard(task: task)
                        .frame(width: 200)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(AppTheme.contentBackground)
    }
}

private struct FocusCard: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(taskLabel, systemImage: taskIcon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(taskIconColor)

            Text(task.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(2)

            if let dateText = dueText {
                Text(dateText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardBackground.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppTheme.cardBorder.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private var taskLabel: String {
        if task.isOverdue { return "Overdue" }
        if task.isFlagged { return "Flagged" }
        return "Focus"
    }

    private var taskIcon: String {
        if task.isOverdue { return "clock.badge.exclamationmark" }
        if task.isFlagged { return "flag.fill" }
        return "sparkles"
    }

    private var taskIconColor: Color {
        if task.isOverdue { return .red }
        if task.isFlagged { return .orange }
        return AppTheme.accent
    }

    private var dueText: String? {
        guard let dueDate = task.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }
}

private enum TaskFilter: CaseIterable {
    case all
    case focus
    case completed

    var title: String {
        switch self {
        case .all: return "All"
        case .focus: return "Focus"
        case .completed: return "Done"
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarTaskList(viewModel: CalendarViewModel())
        .environmentObject(AppState())
        .frame(width: 350, height: 400)
}
