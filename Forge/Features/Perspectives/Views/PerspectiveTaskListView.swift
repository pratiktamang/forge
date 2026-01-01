import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct PerspectiveTaskListView: View {
    let perspectiveId: String
    @StateObject private var viewModel: PerspectiveDetailViewModel
    @EnvironmentObject var appState: AppState

    init(perspectiveId: String) {
        self.perspectiveId = perspectiveId
        _viewModel = StateObject(wrappedValue: PerspectiveDetailViewModel(perspectiveId: perspectiveId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                loadingView
            } else if viewModel.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle(viewModel.perspective?.title ?? "Perspective")
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    private var taskList: some View {
        List(selection: $appState.selectedTaskId) {
            ForEach(viewModel.tasks) { task in
                PerspectiveTaskRow(
                    task: task,
                    onToggleComplete: {
                        AsyncTask {
                            if task.status == .completed {
                                await viewModel.uncompleteTask(task)
                            } else {
                                await viewModel.completeTask(task)
                            }
                        }
                    }
                )
                .tag(task.id)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        .listStyle(.inset)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading tasks...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if let perspective = viewModel.perspective {
                Image(systemName: perspective.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No matching tasks")
                    .font(.headline)

                Text("Tasks matching this perspective's filters will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Perspective not found")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Row

struct PerspectiveTaskRow: View {
    let task: Task
    let onToggleComplete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Completion button
            Button(action: onToggleComplete) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.status == .completed ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.title)
                        .strikethrough(task.status == .completed)
                        .foregroundColor(task.status == .completed ? .secondary : .primary)

                    if task.isFlagged {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                HStack(spacing: 8) {
                    if task.priority != .none {
                        Text(task.priority.displayName)
                            .font(.caption)
                            .foregroundColor(Color(hex: task.priority.color))
                    }

                    if let dueDate = task.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(task.isOverdue ? .red : .secondary)
                    }

                    Text(task.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
