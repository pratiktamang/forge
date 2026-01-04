import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @State private var isDuePickerPresented = false
    @State private var isDeferPickerPresented = false
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
            VStack(alignment: .leading, spacing: 16) {
                // Header: checkbox + title
                headerSection(task)

                // Property pills
                propertyPillsRow(task)

                // Subtasks
                subtasksSection
                    .padding(.top, 8)

                Divider()
                    .padding(.vertical, 8)

                // Notes
                notesSection(task)

                Spacer()
            }
            .padding(24)
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(_ task: Task) -> some View {
        TextField("Task title", text: Binding(
            get: { viewModel.task?.title ?? "" },
            set: { viewModel.task?.title = $0 }
        ))
        .font(.title3.weight(.semibold))
        .textFieldStyle(.plain)
        .focused($isTitleFocused)
        .onSubmit {
            AsyncTask { await viewModel.save() }
        }
    }

    // MARK: - Property Pills Row

    @ViewBuilder
    private func propertyPillsRow(_ task: Task) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today) ?? today

        HStack(spacing: 6) {
            // Project pill
            PropertyPill(
                icon: "folder.fill",
                value: projectSummary(task),
                color: projectColor(task)
            ) {
                Button("Inbox") {
                    viewModel.task?.projectId = nil
                    AsyncTask { await viewModel.save() }
                }
                Divider()
                ForEach(viewModel.projects) { project in
                    Button(project.title) {
                        viewModel.task?.projectId = project.id
                        AsyncTask { await viewModel.save() }
                    }
                }
            }

            // Status pill
            PropertyPill(
                icon: task.status.icon,
                value: task.status.displayName,
                color: statusColor(task.status)
            ) {
                ForEach(TaskStatus.allCases, id: \.self) { status in
                    Button {
                        viewModel.task?.status = status
                        if status == .completed {
                            viewModel.task?.completedAt = Date()
                        } else {
                            viewModel.task?.completedAt = nil
                        }
                        AsyncTask { await viewModel.save() }
                    } label: {
                        Label(status.displayName, systemImage: status.icon)
                    }
                }
            }

            // Due date pill (always visible)
            PropertyPill(
                icon: "calendar",
                value: task.dueDate != nil ? dateSummary(task.dueDate) : "Due",
                color: task.dueDate != nil ? dueDateColor(task.dueDate) : Color.gray.opacity(0.5),
                showBackground: task.dueDate != nil
            ) {
                if task.dueDate != nil {
                    Button("Clear") {
                        viewModel.task?.dueDate = nil
                        AsyncTask { await viewModel.save() }
                    }
                    Divider()
                }
                Button("Today") {
                    viewModel.task?.dueDate = today
                    AsyncTask { await viewModel.save() }
                }
                Button("Tomorrow") {
                    viewModel.task?.dueDate = tomorrow
                    AsyncTask { await viewModel.save() }
                }
                Button("Next Week") {
                    viewModel.task?.dueDate = nextWeek
                    AsyncTask { await viewModel.save() }
                }
                Divider()
                Button("Pick Date...") {
                    isDuePickerPresented = true
                }
            }
            .popover(isPresented: $isDuePickerPresented) {
                datePickerPopover(title: "Due Date", date: Binding(
                    get: { viewModel.task?.dueDate ?? today },
                    set: {
                        viewModel.task?.dueDate = $0
                        AsyncTask { await viewModel.save() }
                    }
                ), onClear: {
                    viewModel.task?.dueDate = nil
                    AsyncTask { await viewModel.save() }
                    isDuePickerPresented = false
                })
            }

            // Flag pill (always visible)
            PropertyPill(
                icon: task.isFlagged ? "flag.fill" : "flag",
                value: task.isFlagged ? "Flagged" : "Flag",
                color: task.isFlagged ? .orange : Color.gray.opacity(0.5),
                showBackground: task.isFlagged
            ) {
                Button(task.isFlagged ? "Remove Flag" : "Add Flag") {
                    viewModel.task?.isFlagged.toggle()
                    AsyncTask { await viewModel.save() }
                }
            }
        }
    }

    // MARK: - Property Helpers

    private func projectSummary(_ task: Task) -> String {
        guard let id = task.projectId else { return "Inbox" }
        return viewModel.projects.first(where: { $0.id == id })?.title ?? "Inbox"
    }

    private func projectColor(_ task: Task) -> Color {
        guard let id = task.projectId,
              let project = viewModel.projects.first(where: { $0.id == id }),
              let hex = project.color else {
            return AppTheme.accent
        }
        return Color(hex: hex)
    }

    private func dateSummary(_ date: Date?) -> String {
        guard let date else { return "None" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func dueDateColor(_ date: Date?) -> Color {
        guard let date else { return .secondary }
        if date < Date() { return .red }
        if Calendar.current.isDateInToday(date) { return .orange }
        return .secondary
    }

    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .inbox: return .secondary
        case .next: return AppTheme.accent
        case .waiting: return .purple
        case .scheduled: return .blue
        case .someday: return .gray
        case .completed: return .green
        case .cancelled: return .red
        }
    }

    @ViewBuilder
    private func datePickerPopover(title: String, date: Binding<Date>, onClear: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            Button("Clear") {
                onClear()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 280, height: 320)
    }

    // MARK: - Subtasks Section

    @ViewBuilder
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUBTASKS")
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                if viewModel.subtasks.isEmpty {
                    Text("No subtasks yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(viewModel.subtasks) { subtask in
                        SubtaskRow(
                            subtask: subtask,
                            onToggle: {
                                AsyncTask { await viewModel.toggleSubtask(subtask) }
                            },
                            onDelete: {
                                AsyncTask { await viewModel.deleteSubtask(subtask) }
                            }
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundColor(AppTheme.accent)

                TextField("Add subtask...", text: $newSubtaskTitle)
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
            .padding(.vertical, 6)
        }
    }

    // MARK: - Notes Section

    @ViewBuilder
    private func notesSection(_ task: Task) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.caption2)
                .foregroundColor(.secondary)

            let notesBinding = Binding(
                get: { viewModel.task?.notes ?? "" },
                set: { viewModel.task?.notes = $0.isEmpty ? nil : $0 }
            )

            ZStack(alignment: .topLeading) {
                if notesBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Write notes…")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 14)
                        .padding(.leading, 14)
                }

                TextEditor(text: notesBinding)
                    .font(.body)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                    )
                    .focused($isNotesFocused)
                    .onChange(of: isNotesFocused) { _, focused in
                        if !focused {
                            AsyncTask { await viewModel.save() }
                        }
                    }
            }
            .frame(minHeight: 220)
        }
    }
}

// MARK: - Property Pill

struct PropertyPill<MenuContent: View>: View {
    let icon: String
    let value: String
    let color: Color
    var showBackground: Bool = true
    @ViewBuilder let menuContent: () -> MenuContent
    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(value)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(showBackground ? color.opacity(isHovered ? 0.18 : 0.1) : (isHovered ? color.opacity(0.1) : Color.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Subtask Row

struct SubtaskRow: View {
    @Environment(\.textScale) private var textScale
    let subtask: Task
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var isCheckboxHovering = false

    var body: some View {
        let iconWidth = 20.0
        let dashSize = 14.0
        let titleFontSize = 14.0 * textScale

        HStack(spacing: 12 * textScale) {
            Button(action: onToggle) {
                if isCheckboxHovering {
                    if subtask.status == .completed {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: (dashSize - 3) * textScale, weight: .medium))
                            .foregroundColor(AppTheme.metadataText)
                            .frame(width: 20 * textScale, height: 20 * textScale)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(AppTheme.metadataText.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: (dashSize - 2) * textScale, weight: .semibold))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 20 * textScale, height: 20 * textScale)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.5), lineWidth: 1)
                            )
                    }
                } else {
                    Text("-")
                        .font(.system(size: dashSize * textScale, weight: .regular, design: .monospaced))
                        .foregroundColor(subtask.status == .completed ? .clear : AppTheme.metadataText.opacity(0.6))
                        .overlay {
                            AnimatedStrikethrough(
                                isActive: subtask.status == .completed,
                                width: iconWidth * textScale
                            )
                        }
                }
            }
            .buttonStyle(.plain)
            .frame(width: iconWidth * textScale)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isCheckboxHovering = hovering
                }
            }

            Text(subtask.title)
                .font(.system(size: titleFontSize, weight: .medium, design: .rounded))
                .foregroundColor(subtask.status == .completed ? AppTheme.metadataText : AppTheme.textPrimary)
                .lineLimit(2)
                .overlay(alignment: .leading) {
                    AnimatedStrikethrough(
                        isActive: subtask.status == .completed && !isCheckboxHovering,
                        leadingPadding: -(12 * textScale + iconWidth * textScale / 2),
                        trailingPadding: -(titleFontSize * 0.6)
                    )
                }

            Spacer()

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button(action: onToggle) {
                Label(
                    subtask.status == .completed ? "Mark Incomplete" : "Mark Complete",
                    systemImage: subtask.status == .completed ? "circle" : "checkmark.circle"
                )
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(taskId: "preview")
        .frame(width: 500, height: 700)
}
