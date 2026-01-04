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
    var onSetStatus: ((TaskStatus) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var canMoveUp: Bool = false
    var canMoveDown: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 14 * textScale) {
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

                // Notes indicator
                if hasMetadata && shouldShowMetadata {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13 * textScale))
                        .foregroundColor(AppTheme.metadataText)
                }
            }

            Spacer()

            // Status badge
            if task.status != .inbox && task.status != .completed && task.status != .next {
                statusBadge
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
        task.notes != nil && !task.notes!.isEmpty
    }

    private var shouldShowMetadata: Bool {
        switch style {
        case .standard:
            return true
        case .minimal:
            return isSelected || isHovering
        }
    }

    // MARK: - Subviews

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
            task: Task(title: "Buy groceries", dueDate: Date(), isFlagged: true),
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
