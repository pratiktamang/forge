import SwiftUI

struct AnimatedStrikethrough: View {
    let isActive: Bool
    var color: Color = AppTheme.metadataText
    var height: CGFloat = 2
    var width: CGFloat? = nil
    var leadingPadding: CGFloat = 0
    var trailingPadding: CGFloat = 0
    var animation: Animation = .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)

    @State private var progress: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: height)
            .scaleEffect(x: progress, y: 1, anchor: .leading)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .accessibilityHidden(true)
            .onAppear {
                progress = isActive ? 1 : 0
            }
            .onChange(of: isActive) { _, active in
                withAnimation(animation) {
                    progress = active ? 1 : 0
                }
            }
    }
}

struct TaskRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.textScale) private var textScale

    enum Style {
        case standard
        case minimal
        case subtask  // For inline subtasks
    }

    let task: Task
    var isSelected: Bool = false
    var style: Style = .standard
    var subtaskInfo: (total: Int, completed: Int)? = nil
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    let onToggleComplete: () -> Void
    let onToggleFlag: () -> Void
    var onSetStatus: ((TaskStatus) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil
    var canMoveUp: Bool = false
    var canMoveDown: Bool = false

    @State private var isHovering = false
    @State private var isCheckboxHovering = false

    private var hasSubtasks: Bool {
        if let info = subtaskInfo { return info.total > 0 }
        return false
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12 * textScale) {
            // Leading element: chevron for parent tasks, checkbox for others
            let iconWidth = style == .subtask ? 20.0 : 24.0
            let titleFontSize = (style == .subtask ? 14.0 : 16.0) * textScale

            if hasSubtasks {
                // Chevron for expandable tasks
                Button(action: { onToggleExpand?() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12 * textScale, weight: .medium))
                        .foregroundColor(AppTheme.metadataText.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(width: iconWidth * textScale)
            } else {
                // Checkbox for leaf tasks
                Button(action: onToggleComplete) {
                    checkbox
                }
                .buttonStyle(.plain)
                .frame(width: iconWidth * textScale)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isCheckboxHovering = hovering
                    }
                }
            }

            // Title
            Text(task.title)
                .font(.system(size: titleFontSize, weight: .medium, design: .rounded))
                .foregroundColor(task.status == .completed ? AppTheme.metadataText : AppTheme.textPrimary)
                .strikethrough(task.status == .completed && hasSubtasks, color: AppTheme.metadataText)
                .lineLimit(2)
                .overlay(alignment: .leading) {
                    // Connected strikethrough line from dash through title
                    if !hasSubtasks {
                        AnimatedStrikethrough(
                            isActive: task.status == .completed && !isCheckboxHovering,
                            leadingPadding: -(12 * textScale + iconWidth * textScale / 2),
                            trailingPadding: -(titleFontSize * 0.6)
                        )
                    }
                }

            Spacer()

            // Subtask count for parent tasks
            if let info = subtaskInfo, info.total > 0 {
                Text("\(info.completed)/\(info.total)")
                    .font(.system(size: 12 * textScale, weight: .medium, design: .rounded))
                    .foregroundColor(info.completed == info.total ? AppTheme.accent : AppTheme.metadataText)
            }

            // Status badge (hide for subtask style)
            if style != .subtask && task.status != .inbox && task.status != .completed && task.status != .next {
                statusBadge
            }
        }
        .padding(.vertical, style == .subtask ? 8 : 14 * textScale)
        .padding(.horizontal, style == .subtask ? 8 : 16 * textScale)
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

    // MARK: - Subviews

    @ViewBuilder
    private var checkbox: some View {
        let size = style == .subtask ? 14.0 : 16.0
        let iconWidth = style == .subtask ? 20.0 : 24.0

        if isCheckboxHovering {
            if task.status == .completed {
                // Show undo arrow on hover for completed tasks
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: (size - 3) * textScale, weight: .medium))
                    .foregroundColor(AppTheme.metadataText)
                    .frame(width: 20 * textScale, height: 20 * textScale)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(AppTheme.metadataText.opacity(0.3), lineWidth: 1)
                    )
            } else {
                // Show checkmark on hover (clickable)
                Image(systemName: "checkmark")
                    .font(.system(size: (size - 2) * textScale, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 20 * textScale, height: 20 * textScale)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1)
                    )
            }
        } else {
            // Show dash (struck through when completed)
            Text("-")
                .font(.system(size: size * textScale, weight: .regular, design: .monospaced))
                .foregroundColor(task.status == .completed ? .clear : AppTheme.metadataText.opacity(0.6))
                .overlay {
                    AnimatedStrikethrough(
                        isActive: task.status == .completed,
                        width: iconWidth * textScale
                    )
                }
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
