import SwiftUI

struct TaskRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.textScale) private var textScale

    enum Style {
        case standard
        case minimal
    }

    let task: Task
    var isSelected: Bool = false
    var style: Style = .standard
    let onToggleComplete: () -> Void
    let onToggleFlag: () -> Void
    var onSetPriority: ((Priority) -> Void)? = nil
    var onSetStatus: ((TaskStatus) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var canMoveUp: Bool = false
    var canMoveDown: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 14 * textScale) {
            // Checkbox
            Button(action: onToggleComplete) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24 * textScale))
                    .foregroundColor(task.status == .completed ? AppTheme.accent : AppTheme.metadataText)
            }
            .buttonStyle(.plain)

            // Content
            VStack(alignment: .leading, spacing: 6 * textScale) {
                // Title
                Text(task.title)
                    .font(.system(size: 16 * textScale, weight: .medium, design: .rounded))
                    .strikethrough(task.status == .completed)
                    .foregroundColor(task.status == .completed ? AppTheme.metadataText : AppTheme.textPrimary)
                    .lineLimit(2)

                // Metadata row
                if hasMetadata && shouldShowMetadata {
                    HStack(spacing: 10 * textScale) {
                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(formatDueDate(dueDate))
                            }
                            .font(.system(size: 13 * textScale))
                            .foregroundColor(dueDateColor(dueDate))
                        }

                        // Defer date
                        if let deferDate = task.deferDate, task.dueDate == nil {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle")
                                Text("Starts \(formatDueDate(deferDate))")
                            }
                            .font(.system(size: 13 * textScale))
                            .foregroundColor(.orange)
                        }

                        // Priority
                        if task.priority != .none {
                            priorityBadge
                        }

                        // Notes indicator
                        if task.notes != nil && !task.notes!.isEmpty {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13 * textScale))
                                .foregroundColor(AppTheme.metadataText)
                        }
                    }
                }
            }

            Spacer()

            // Right side actions
            if shouldShowActions {
                HStack(spacing: 10 * textScale) {
                    // Flag button
                    Button(action: onToggleFlag) {
                        Image(systemName: task.isFlagged ? "flag.fill" : "flag")
                            .font(.system(size: 18 * textScale))
                            .foregroundColor(task.isFlagged ? Color(hex: "E07A3F") : AppTheme.metadataText)
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering || task.isFlagged ? 1 : (style == .minimal ? 0 : 1))

                    // Status badge
                    if task.status != .inbox && task.status != .completed && task.status != .next {
                        statusBadge
                    }
                }
            }
        }
        .padding(.vertical, 14 * textScale)
        .padding(.horizontal, 16 * textScale)
        .background(rowBackground)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
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

    private var shouldShowMetadata: Bool {
        switch style {
        case .standard:
            return true
        case .minimal:
            return isSelected || isHovering
        }
    }

    private var shouldShowActions: Bool {
        switch style {
        case .standard:
            return true
        case .minimal:
            return isSelected || isHovering || task.isFlagged
        }
    }

    // MARK: - Subviews

    private var priorityBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(task.priority.displayName)
        }
        .font(.system(size: 13 * textScale))
        .foregroundColor(priorityColor)
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return Color(hex: "E07A3F")
        case .medium: return AppTheme.sidebarHeaderText
        case .low: return AppTheme.metadataText
        case .none: return AppTheme.metadataText
        }
    }

    private var statusBadge: some View {
        Text(task.status.displayName)
            .font(.system(size: 11 * textScale))
            .padding(.horizontal, 8 * textScale)
            .padding(.vertical, 3 * textScale)
            .background(AppTheme.sidebarHeaderBackground.opacity(0.7))
            .foregroundColor(AppTheme.sidebarHeaderText)
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

        Menu("Priority") {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button(action: { onSetPriority?(priority) }) {
                    HStack {
                        Text(priority.displayName)
                        if task.priority == priority {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Menu("Status") {
            ForEach([TaskStatus.inbox, .next, .waiting, .scheduled, .someday], id: \.self) { status in
                Button(action: { onSetStatus?(status) }) {
                    HStack {
                        Label(status.displayName, systemImage: statusIcon(status))
                        if task.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Divider()

        if canMoveUp, let onMoveUp {
            Button("Move Up", action: onMoveUp)
        }

        if canMoveDown, let onMoveDown {
            Button("Move Down", action: onMoveDown)
        }

        if (canMoveUp && onMoveUp != nil) || (canMoveDown && onMoveDown != nil) {
            Divider()
        }

        if let onDelete = onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func statusIcon(_ status: TaskStatus) -> String {
        switch status {
        case .inbox: return "tray"
        case .next: return "arrow.right.circle"
        case .waiting: return "clock"
        case .scheduled: return "calendar"
        case .someday: return "moon.zzz"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
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
            return Color(hex: "E07A3F") // Overdue
        } else if calendar.isDateInToday(date) {
            return AppTheme.sidebarHeaderText // Due today
        } else if calendar.isDateInTomorrow(date) {
            return AppTheme.metadataText // Due tomorrow
        } else {
            return AppTheme.metadataText
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return AppTheme.selectionBackground
        } else if isHovering {
            return AppTheme.contentBackground.opacity(0.8)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        TaskRowView(
            task: Task(title: "Buy groceries", priority: .high, dueDate: Date(), isFlagged: true),
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
