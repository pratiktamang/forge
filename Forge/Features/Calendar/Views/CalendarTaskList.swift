import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct CalendarTaskList: View {
    @ObservedObject var viewModel: CalendarViewModel
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle = ""
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
        List(selection: $appState.selectedTaskId) {
            ForEach(viewModel.tasksForSelectedDate) { task in
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
            }
            .onDelete(perform: deleteTasks)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.contentBackground)
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

    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = viewModel.tasksForSelectedDate[index]
            AsyncTask {
                await viewModel.deleteTask(task)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarTaskList(viewModel: CalendarViewModel())
        .environmentObject(AppState())
        .frame(width: 350, height: 400)
}
