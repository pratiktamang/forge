import SwiftUI

struct TaskRowView: View {
    let task: Task
    let onToggleComplete: () -> Void
    let onToggleFlag: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggleComplete) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.status == .completed)
                    .foregroundColor(task.status == .completed ? .secondary : .primary)
                    .lineLimit(2)

                // Metadata row
                if hasMetadata {
                    HStack(spacing: 8) {
                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(formatDueDate(dueDate))
                            }
                            .font(.caption)
                            .foregroundColor(dueDateColor(dueDate))
                        }

                        // Defer date
                        if let deferDate = task.deferDate, task.dueDate == nil {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle")
                                Text("Starts \(formatDueDate(deferDate))")
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }

                        // Priority
                        if task.priority != .none {
                            priorityBadge
                        }

                        // Notes indicator
                        if task.notes != nil && !task.notes!.isEmpty {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Right side actions
            HStack(spacing: 8) {
                // Flag button
                Button(action: onToggleFlag) {
                    Image(systemName: task.isFlagged ? "flag.fill" : "flag")
                        .foregroundColor(task.isFlagged ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || task.isFlagged ? 1 : 0)

                // Status badge
                if task.status != .inbox && task.status != .completed && task.status != .next {
                    statusBadge
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Computed Properties

    private var hasMetadata: Bool {
        task.dueDate != nil ||
        task.deferDate != nil ||
        task.priority != .none ||
        (task.notes != nil && !task.notes!.isEmpty)
    }

    // MARK: - Subviews

    private var priorityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(task.priority.displayName)
        }
        .font(.caption)
        .foregroundColor(priorityColor)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .secondary
        }
    }

    private var statusBadge: some View {
        Text(task.status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onToggleComplete) {
            Label(
                task.status == .completed ? "Mark Incomplete" : "Mark Complete",
                systemImage: task.status == .completed ? "circle" : "checkmark.circle"
            )
        }

        Button(action: onToggleFlag) {
            Label(
                task.isFlagged ? "Remove Flag" : "Add Flag",
                systemImage: task.isFlagged ? "flag.slash" : "flag"
            )
        }

        Divider()

        Menu("Set Priority") {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button(priority.displayName) {
                    // Handle priority change
                }
            }
        }

        Menu("Move to") {
            Button("Inbox") { }
            Divider()
            // Projects would go here
        }

        Divider()

        Button(role: .destructive) {
            // Handle delete
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            return formatter.string(from: date)
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: date)

        if dueDay < today {
            return .red // Overdue
        } else if calendar.isDateInToday(date) {
            return .orange // Due today
        } else if calendar.isDateInTomorrow(date) {
            return .yellow // Due tomorrow
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        TaskRowView(
            task: Task(title: "Buy groceries", dueDate: Date(), priority: .high, isFlagged: true),
            onToggleComplete: {},
            onToggleFlag: {}
        )
        Divider()
        TaskRowView(
            task: Task(title: "Review pull request", notes: "Check the API changes"),
            onToggleComplete: {},
            onToggleFlag: {}
        )
        Divider()
        TaskRowView(
            task: Task(title: "Completed task", status: .completed),
            onToggleComplete: {},
            onToggleFlag: {}
        )
    }
    .padding()
    .frame(width: 400)
}
