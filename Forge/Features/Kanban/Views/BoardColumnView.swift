import SwiftUI
import UniformTypeIdentifiers

struct BoardColumnView: View {
    let column: BoardColumn
    let tasks: [Task]
    let isOverWipLimit: Bool
    let onAddTask: (String) -> Void
    let onMoveTask: (String?) -> Void
    let onDeleteColumn: () -> Void
    let onUpdateColumn: (BoardColumn) -> Void

    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var isTargeted = false
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isNewTaskFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            columnHeader

            Divider()

            // Tasks
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        BoardCardView(task: task)
                            .draggable(TaskDragItem(taskId: task.id, sourceColumnId: column.id))
                    }

                    // Add task inline
                    if isAddingTask {
                        addTaskInline
                    }
                }
                .padding(8)
            }

            // Add task button
            if !isAddingTask {
                addTaskButton
            }
        }
        .frame(width: 280)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let item = items.first else { return false }
            onMoveTask(item.taskId)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    // MARK: - Column Header

    private var columnHeader: some View {
        HStack(spacing: 8) {
            // Color indicator
            if let colorHex = column.color {
                Circle()
                    .fill(Color(hex: colorHex) ?? .gray)
                    .frame(width: 8, height: 8)
            }

            // Title
            if isEditingTitle {
                TextField("Column name", text: $editedTitle)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .onSubmit {
                        saveTitle()
                    }
                    .onAppear {
                        editedTitle = column.title
                    }
            } else {
                Text(column.title)
                    .font(.headline)
                    .onTapGesture(count: 2) {
                        isEditingTitle = true
                    }
            }

            // Task count / WIP
            HStack(spacing: 4) {
                Text("\(tasks.count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isOverWipLimit ? Color.red.opacity(0.2) : Color.secondary.opacity(0.2))
                    .foregroundColor(isOverWipLimit ? .red : .secondary)
                    .cornerRadius(4)

                if let wipLimit = column.wipLimit {
                    Text("/\(wipLimit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Menu
            Menu {
                Button("Edit Column") {
                    isEditingTitle = true
                }

                if column.wipLimit == nil {
                    Button("Set WIP Limit") {
                        // TODO: Show WIP limit dialog
                    }
                } else {
                    Button("Remove WIP Limit") {
                        var updated = column
                        updated.wipLimit = nil
                        onUpdateColumn(updated)
                    }
                }

                Divider()

                Button("Delete Column", role: .destructive) {
                    onDeleteColumn()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Add Task

    private var addTaskButton: some View {
        Button(action: {
            isAddingTask = true
            isNewTaskFocused = true
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add Task")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var addTaskInline: some View {
        VStack(spacing: 8) {
            TextField("Task title", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isNewTaskFocused)
                .onSubmit {
                    addTask()
                }

            HStack {
                Button("Cancel") {
                    isAddingTask = false
                    newTaskTitle = ""
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Add") {
                    addTask()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newTaskTitle.isEmpty)
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onAddTask(newTaskTitle)
        newTaskTitle = ""
        isAddingTask = false
    }

    private func saveTitle() {
        guard !editedTitle.isEmpty else {
            isEditingTitle = false
            return
        }
        var updated = column
        updated.title = editedTitle
        onUpdateColumn(updated)
        isEditingTitle = false
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        BoardColumnView(
            column: BoardColumn(boardId: "1", title: "To Do", color: "#6B7280", sortOrder: 0),
            tasks: [
                Task(title: "Design homepage"),
                Task(title: "Write documentation", priority: .high)
            ],
            isOverWipLimit: false,
            onAddTask: { _ in },
            onMoveTask: { _ in },
            onDeleteColumn: {},
            onUpdateColumn: { _ in }
        )

        BoardColumnView(
            column: BoardColumn(boardId: "1", title: "In Progress", color: "#3B82F6", sortOrder: 1, wipLimit: 3),
            tasks: [
                Task(title: "Implement login", dueDate: Date()),
                Task(title: "Setup database"),
                Task(title: "API endpoints"),
                Task(title: "Over limit task")
            ],
            isOverWipLimit: true,
            onAddTask: { _ in },
            onMoveTask: { _ in },
            onDeleteColumn: {},
            onUpdateColumn: { _ in }
        )
    }
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}
