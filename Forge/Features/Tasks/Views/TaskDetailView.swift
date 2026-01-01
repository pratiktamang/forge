import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isSubtaskFocused: Bool

    init(taskId: String) {
        _viewModel = StateObject(wrappedValue: TaskDetailViewModel(taskId: taskId))
    }

    var body: some View {
        Group {
            if let task = viewModel.task {
                taskDetailContent(task)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Task not found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Task Detail Content

    @ViewBuilder
    private func taskDetailContent(_ task: Task) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection(task)

                Divider()

                // Properties
                propertiesSection(task)

                Divider()

                // Notes
                notesSection(task)

                Divider()

                // Subtasks
                subtasksSection

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(_ task: Task) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Completion checkbox
            Button(action: {
                AsyncTask {
                    if task.status == .completed {
                        var updated = task
                        updated.status = .next
                        updated.completedAt = nil
                        viewModel.task = updated
                        await viewModel.save()
                    } else {
                        var updated = task
                        updated.status = .completed
                        updated.completedAt = Date()
                        viewModel.task = updated
                        await viewModel.save()
                    }
                }
            }) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundColor(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Title
            VStack(alignment: .leading, spacing: 8) {
                TextField("Task title", text: Binding(
                    get: { viewModel.task?.title ?? "" },
                    set: { viewModel.task?.title = $0 }
                ))
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .focused($isTitleFocused)
                .onSubmit {
                    AsyncTask { await viewModel.save() }
                }

                // Status and created info
                HStack(spacing: 12) {
                    statusMenu(task)

                    Text("Created \(task.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Flag button
            Button(action: {
                viewModel.task?.isFlagged.toggle()
                AsyncTask { await viewModel.save() }
            }) {
                Image(systemName: task.isFlagged ? "flag.fill" : "flag")
                    .font(.title2)
                    .foregroundColor(task.isFlagged ? .orange : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Properties Section

    @ViewBuilder
    private func propertiesSection(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Properties")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Due Date
                propertyRow(
                    icon: "calendar",
                    label: "Due Date",
                    content: {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.task?.dueDate ?? Date() },
                                set: {
                                    viewModel.task?.dueDate = $0
                                    AsyncTask { await viewModel.save() }
                                }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                )

                // Defer Date
                propertyRow(
                    icon: "arrow.right.circle",
                    label: "Defer Until",
                    content: {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.task?.deferDate ?? Date() },
                                set: {
                                    viewModel.task?.deferDate = $0
                                    AsyncTask { await viewModel.save() }
                                }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                )

                // Priority
                propertyRow(
                    icon: "exclamationmark.circle",
                    label: "Priority",
                    content: {
                        Picker("", selection: Binding(
                            get: { viewModel.task?.priority ?? .none },
                            set: {
                                viewModel.task?.priority = $0
                                AsyncTask { await viewModel.save() }
                            }
                        )) {
                            ForEach(Priority.allCases, id: \.self) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .labelsHidden()
                    }
                )

                // Estimated time
                propertyRow(
                    icon: "clock",
                    label: "Estimate",
                    content: {
                        TextField(
                            "minutes",
                            value: Binding(
                                get: { viewModel.task?.estimatedMinutes },
                                set: { viewModel.task?.estimatedMinutes = $0 }
                            ),
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            AsyncTask { await viewModel.save() }
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func propertyRow<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Status Menu

    @ViewBuilder
    private func statusMenu(_ task: Task) -> some View {
        Menu {
            ForEach(TaskStatus.allCases, id: \.self) { status in
                Button(action: {
                    viewModel.task?.status = status
                    if status == .completed {
                        viewModel.task?.completedAt = Date()
                    } else {
                        viewModel.task?.completedAt = nil
                    }
                    AsyncTask { await viewModel.save() }
                }) {
                    Label(status.displayName, systemImage: status.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: task.status.icon)
                Text(task.status.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Notes Section

    @ViewBuilder
    private func notesSection(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            TextEditor(text: Binding(
                get: { viewModel.task?.notes ?? "" },
                set: { viewModel.task?.notes = $0.isEmpty ? nil : $0 }
            ))
            .font(.body)
            .frame(minHeight: 100)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .focused($isNotesFocused)
            .onChange(of: isNotesFocused) { _, focused in
                if !focused {
                    AsyncTask { await viewModel.save() }
                }
            }
        }
    }

    // MARK: - Subtasks Section

    @ViewBuilder
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subtasks")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.subtasks.filter { $0.status == .completed }.count)/\(viewModel.subtasks.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Subtask list
            VStack(spacing: 8) {
                ForEach(viewModel.subtasks) { subtask in
                    HStack(spacing: 12) {
                        Button(action: {
                            AsyncTask { await viewModel.toggleSubtask(subtask) }
                        }) {
                            Image(systemName: subtask.status == .completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(subtask.status == .completed ? .green : .secondary)
                        }
                        .buttonStyle(.plain)

                        Text(subtask.title)
                            .strikethrough(subtask.status == .completed)
                            .foregroundColor(subtask.status == .completed ? .secondary : .primary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // Add subtask
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.secondary)

                    TextField("Add subtask", text: $newSubtaskTitle)
                        .textFieldStyle(.plain)
                        .focused($isSubtaskFocused)
                        .onSubmit {
                            guard !newSubtaskTitle.isEmpty else { return }
                            AsyncTask {
                                await viewModel.addSubtask(title: newSubtaskTitle)
                                newSubtaskTitle = ""
                            }
                        }
                }
                .padding(.vertical, 4)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(taskId: "preview")
        .frame(width: 500, height: 700)
}
