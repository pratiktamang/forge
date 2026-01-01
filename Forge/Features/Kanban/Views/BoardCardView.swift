import SwiftUI

struct BoardCardView: View {
    let task: Task
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(task.title)
                .font(.subheadline.weight(.medium))
                .lineLimit(3)
                .foregroundColor(task.status == .completed ? .secondary : .primary)
                .strikethrough(task.status == .completed)

            // Metadata
            if hasMetadata {
                HStack(spacing: 8) {
                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(formatDate(dueDate))
                        }
                        .font(.caption2)
                        .foregroundColor(dueDateColor(dueDate))
                    }

                    // Priority
                    if task.priority != .none {
                        priorityIndicator
                    }

                    Spacer()

                    // Flag
                    if task.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    // Notes indicator
                    if task.notes != nil && !task.notes!.isEmpty {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Tags placeholder
            // TODO: Add tags display
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 4 : 2, y: isHovering ? 2 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            contextMenu
        }
    }

    // MARK: - Computed Properties

    private var hasMetadata: Bool {
        task.dueDate != nil ||
        task.priority != .none ||
        task.isFlagged ||
        (task.notes != nil && !task.notes!.isEmpty)
    }

    // MARK: - Subviews

    private var priorityIndicator: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(priorityColor)
                .frame(width: 6, height: 6)
            Text(task.priority.displayName)
                .font(.caption2)
                .foregroundColor(priorityColor)
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        case .none: return .secondary
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            // Toggle complete
        } label: {
            Label(
                task.status == .completed ? "Mark Incomplete" : "Mark Complete",
                systemImage: task.status == .completed ? "circle" : "checkmark.circle"
            )
        }

        Button {
            // Toggle flag
        } label: {
            Label(
                task.isFlagged ? "Remove Flag" : "Add Flag",
                systemImage: task.isFlagged ? "flag.slash" : "flag"
            )
        }

        Divider()

        Menu("Set Priority") {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button(priority.displayName) {
                    // Set priority
                }
            }
        }

        Menu("Move to Column") {
            // Column options would go here
            Text("Column options...")
        }

        Divider()

        Button(role: .destructive) {
            // Delete
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func dueDateColor(_ date: Date) -> Color {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: date)

        if dueDay < today {
            return .red
        } else if calendar.isDateInToday(date) {
            return .orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        BoardCardView(
            task: Task(
                title: "Design the new homepage with updated branding",
                dueDate: Date(),
                priority: .high,
                isFlagged: true
            )
        )

        BoardCardView(
            task: Task(
                title: "Review pull request",
                notes: "Check the API changes and ensure backward compatibility"
            )
        )

        BoardCardView(
            task: Task(
                title: "Simple task"
            )
        )

        BoardCardView(
            task: Task(
                title: "Completed task",
                status: .completed
            )
        )
    }
    .padding()
    .frame(width: 280)
    .background(Color(nsColor: .controlBackgroundColor))
}
