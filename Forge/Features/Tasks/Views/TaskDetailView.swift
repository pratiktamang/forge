import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @State private var isHoveringProperties = false
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

                // Property pills (show on hover)
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
        HStack(alignment: .top, spacing: 12) {
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
                    .font(.title2)
                    .foregroundColor(task.status == .completed ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

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
    }

    // MARK: - Property Pills Row

    @ViewBuilder
    private func propertyPillsRow(_ task: Task) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today) ?? today

        HStack(spacing: 2) {
            // Project pill
            PropertyPill(
                icon: "folder",
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

            pillSeparator

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

            // Priority pill (only show if set)
            if task.priority != .none {
                pillSeparator
                PropertyPill(
                    icon: "bolt.fill",
                    value: task.priority.displayName,
                    color: priorityColor(task.priority)
                ) {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Button {
                            viewModel.task?.priority = priority
                            AsyncTask { await viewModel.save() }
                        } label: {
                            HStack {
                                Text(priority.displayName)
                                if task.priority == priority {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // Due date pill (only show if set)
            if task.dueDate != nil {
                pillSeparator
                PropertyPill(
                    icon: "calendar",
                    value: dateSummary(task.dueDate),
                    color: dueDateColor(task.dueDate)
                ) {
                    Button("Clear") {
                        viewModel.task?.dueDate = nil
                        AsyncTask { await viewModel.save() }
                    }
                    Divider()
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
            }

            // Flag indicator
            if task.isFlagged {
                pillSeparator
                Button {
                    viewModel.task?.isFlagged = false
                    AsyncTask { await viewModel.save() }
                } label: {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Add property button (shows on hover)
            addPropertyMenu(task, today: today, tomorrow: tomorrow, nextWeek: nextWeek)
        }
        .padding(.leading, 36) // Align with title (after checkbox)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringProperties = hovering
            }
        }
    }

    private var pillSeparator: some View {
        Text("·")
            .font(.system(size: 10))
            .foregroundColor(AppTheme.textSecondary.opacity(0.5))
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func addPropertyMenu(_ task: Task, today: Date, tomorrow: Date, nextWeek: Date) -> some View {
        Menu {
            if task.priority == .none {
                Menu("Priority") {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        Button(priority.displayName) {
                            viewModel.task?.priority = priority
                            AsyncTask { await viewModel.save() }
                        }
                    }
                }
            }

            if task.dueDate == nil {
                Menu("Due Date") {
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
                }
            }

            if task.deferDate == nil {
                Menu("Defer Until") {
                    Button("Tomorrow") {
                        viewModel.task?.deferDate = tomorrow
                        AsyncTask { await viewModel.save() }
                    }
                    Button("Next Week") {
                        viewModel.task?.deferDate = nextWeek
                        AsyncTask { await viewModel.save() }
                    }
                }
            }

            if !task.isFlagged {
                Button {
                    viewModel.task?.isFlagged = true
                    AsyncTask { await viewModel.save() }
                } label: {
                    Label("Flag", systemImage: "flag")
                }
            } else {
                Button {
                    viewModel.task?.isFlagged = false
                    AsyncTask { await viewModel.save() }
                } label: {
                    Label("Unflag", systemImage: "flag.slash")
                }
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .opacity(isHoveringProperties ? 1 : 0)
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

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .none: return .secondary
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
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
    @ViewBuilder let menuContent: () -> MenuContent
    @State private var isHovered = false

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(value)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isHovered ? color : AppTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? color.opacity(0.12) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Subtask Row

struct SubtaskRow: View {
    let subtask: Task
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: subtask.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subtask.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(subtask.title)
                .strikethrough(subtask.status == .completed)
                .foregroundColor(subtask.status == .completed ? .secondary : .primary)

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
