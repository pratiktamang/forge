import SwiftUI

struct BoardCardView: View {
    let task: Task
    let tags: [Tag]
    var onToggleComplete: (() -> Void)?
    var onToggleFlag: (() -> Void)?
    var onSetPriority: ((Priority) -> Void)?
    var onDelete: (() -> Void)?

    @State private var isHovering = false

    init(task: Task, tags: [Tag] = [], onToggleComplete: (() -> Void)? = nil, onToggleFlag: (() -> Void)? = nil, onSetPriority: ((Priority) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.task = task
        self.tags = tags
        self.onToggleComplete = onToggleComplete
        self.onToggleFlag = onToggleFlag
        self.onSetPriority = onSetPriority
        self.onDelete = onDelete
    }

    private var isHighPriority: Bool {
        task.priority == .high || task.isFlagged
    }

    private var glowColor: Color {
        if task.priority == .high { return Color.orange }
        if task.isFlagged { return Color.yellow }
        return Color.clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(3)
                .foregroundColor(task.status == .completed ? .secondary : AppTheme.textPrimary)
                .strikethrough(task.status == .completed)

            // Tags
            if !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags.prefix(3)) { tag in
                        Text(tag.name)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: tag.color ?? "8E8E93").opacity(0.2))
                            .foregroundColor(Color(hex: tag.color ?? "8E8E93"))
                            .cornerRadius(4)
                    }
                    if tags.count > 3 {
                        Text("+\(tags.count - 3)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Bottom metadata row
            if hasMetadata {
                HStack(spacing: 6) {
                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(formatDate(dueDate))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(dueDateColor(dueDate))
                    }

                    Spacer()

                    // Notes indicator
                    if task.notes != nil && !task.notes!.isEmpty {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isHighPriority ? glowColor.opacity(0.6) : AppTheme.cardBorder, lineWidth: isHighPriority ? 2 : 1)
        )
        .shadow(color: isHighPriority ? glowColor.opacity(0.3) : .black.opacity(0.05), radius: isHighPriority ? 8 : 2, y: 1)
        .scaleEffect(isHovering ? 1.02 : 1.0)
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
        task.dueDate != nil || (task.notes != nil && !task.notes!.isEmpty)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button {
            onToggleComplete?()
        } label: {
            Label(
                task.status == .completed ? "Mark Incomplete" : "Mark Complete",
                systemImage: task.status == .completed ? "circle" : "checkmark.circle"
            )
        }

        Button {
            onToggleFlag?()
        } label: {
            Label(
                task.isFlagged ? "Remove Flag" : "Add Flag",
                systemImage: task.isFlagged ? "flag.slash" : "flag"
            )
        }

        Divider()

        Menu("Priority") {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    onSetPriority?(priority)
                } label: {
                    if task.priority == priority {
                        Label(priority.displayName, systemImage: "checkmark")
                    } else {
                        Text(priority.displayName)
                    }
                }
            }
        }

        Divider()

        Button(role: .destructive) {
            onDelete?()
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
    VStack(spacing: 12) {
        // High priority with glow
        BoardCardView(
            task: Task(
                title: "Design the new homepage with updated branding",
                priority: .high,
                dueDate: Date()
            ),
            tags: [
                Tag(name: "design", color: "AF52DE", tagType: .tag),
                Tag(name: "urgent", color: "FF3B30", tagType: .context)
            ]
        )

        // Flagged with golden glow
        BoardCardView(
            task: Task(
                title: "Review pull request before release",
                notes: "Check the API changes",
                isFlagged: true
            ),
            tags: [Tag(name: "review", color: "007AFF", tagType: .tag)]
        )

        // Normal card
        BoardCardView(
            task: Task(
                title: "Simple task without priority"
            )
        )

        // Completed card
        BoardCardView(
            task: Task(
                title: "Completed task",
                status: .completed
            )
        )
    }
    .padding(16)
    .frame(width: 300)
    .background(AppTheme.contentBackground)
}
