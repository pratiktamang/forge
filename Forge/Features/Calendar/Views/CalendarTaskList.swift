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
                    .font(.headline)

                Spacer()

                Text("\(viewModel.tasksForSelectedDate.count) tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if viewModel.tasksForSelectedDate.isEmpty && !isAddingTask {
                emptyState
            } else {
                taskList
            }

            // Quick add bar
            quickAddBar
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        List(selection: $appState.selectedTaskId) {
            ForEach(viewModel.tasksForSelectedDate) { task in
                TaskRowView(
                    task: task,
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
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("No tasks scheduled")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { isAddingTask = true }) {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.accentColor)
                .font(.title2)

            TextField("Add task for \(shortDateString)...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .focused($isAddingTask)
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
