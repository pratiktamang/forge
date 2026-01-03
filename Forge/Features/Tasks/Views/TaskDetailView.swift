import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @State private var newTagName = ""
    @State private var isAddingTag = false
    @State private var newTagType: TagType = .tag
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
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection(task)

                Divider()

                // Properties
                propertiesSection(task)

                Divider()

                // Tags
                tagsSection

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
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: today) ?? today

        VStack(alignment: .leading, spacing: 0) {
            // Project
            propertyRow(icon: "folder", label: "Project") {
                Menu {
                    Button("None") {
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
                } label: {
                    HStack(spacing: 4) {
                        Text(projectSummary(task))
                            .foregroundColor(task.projectId == nil ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
            }

            Divider().padding(.leading, 32)

            // Due Date
            propertyRow(icon: "calendar", label: "Due Date") {
                Menu {
                    Button("None") {
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
                } label: {
                    HStack(spacing: 4) {
                        Text(dateSummary(task.dueDate))
                            .foregroundColor(task.dueDate == nil ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
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

            Divider().padding(.leading, 32)

            // Defer Date
            propertyRow(icon: "arrow.right.circle", label: "Defer Until") {
                Menu {
                    Button("None") {
                        viewModel.task?.deferDate = nil
                        AsyncTask { await viewModel.save() }
                    }
                    Divider()
                    Button("Tomorrow") {
                        viewModel.task?.deferDate = tomorrow
                        AsyncTask { await viewModel.save() }
                    }
                    Button("Next Week") {
                        viewModel.task?.deferDate = nextWeek
                        AsyncTask { await viewModel.save() }
                    }
                    Divider()
                    Button("Pick Date...") {
                        isDeferPickerPresented = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(dateSummary(task.deferDate))
                            .foregroundColor(task.deferDate == nil ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .popover(isPresented: $isDeferPickerPresented) {
                    datePickerPopover(title: "Defer Until", date: Binding(
                        get: { viewModel.task?.deferDate ?? today },
                        set: {
                            viewModel.task?.deferDate = $0
                            AsyncTask { await viewModel.save() }
                        }
                    ), onClear: {
                        viewModel.task?.deferDate = nil
                        AsyncTask { await viewModel.save() }
                        isDeferPickerPresented = false
                    })
                }
            }

            Divider().padding(.leading, 32)

            // Priority
            propertyRow(icon: "exclamationmark.circle", label: "Priority") {
                Menu {
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
                } label: {
                    HStack(spacing: 4) {
                        Text(prioritySummary(task))
                            .foregroundColor(task.priority == .none ? .secondary : Color(hex: task.priority.color))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
            }

            Divider().padding(.leading, 32)

            // Estimate
            propertyRow(icon: "clock", label: "Estimate") {
                HStack(spacing: 8) {
                    Stepper(value: Binding(
                        get: { viewModel.task?.estimatedMinutes ?? 0 },
                        set: {
                            viewModel.task?.estimatedMinutes = max(0, $0)
                            AsyncTask { await viewModel.save() }
                        }
                    ), in: 0...1440, step: 5) {
                        Text(estimateSummary(task))
                            .foregroundColor((task.estimatedMinutes ?? 0) == 0 ? .secondary : .primary)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func propertyRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    private func dateSummary(_ date: Date?) -> String {
        guard let date else { return "None" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func prioritySummary(_ task: Task) -> String {
        task.priority.displayName
    }

    private func projectSummary(_ task: Task) -> String {
        guard let id = task.projectId else { return "None" }
        return viewModel.projects.first(where: { $0.id == id })?.title ?? "None"
    }

    private func estimateSummary(_ task: Task) -> String {
        guard let minutes = task.estimatedMinutes, minutes > 0 else { return "No estimate" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 {
            return "\(minutes) min"
        } else if remainder == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(remainder)m"
        }
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

    // MARK: - Tags Section

    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tags")
                    .font(.headline)

                Spacer()

                Menu {
                    if availableTags.isEmpty {
                        Button("All tags added") {}
                            .disabled(true)
                    } else {
                        ForEach(availableTags) { tag in
                            Button {
                                AsyncTask { await viewModel.addTag(tag) }
                            } label: {
                                Label(tag.displayName, systemImage: "tag")
                            }
                        }
                    }

                    Divider()

                    Button {
                        isAddingTag = true
                    } label: {
                        Label("Create New Tag", systemImage: "plus.circle")
                    }
                } label: {
                    Label("Add Tag", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .menuStyle(.borderedButton)
                .controlSize(.small)
                .popover(isPresented: $isAddingTag) {
                    addTagPopover
                }
            }

            // Current tags
            if viewModel.taskTags.isEmpty {
                Text("No tags")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                TaskDetailFlowLayout(spacing: 8) {
                    ForEach(viewModel.taskTags) { tag in
                        TagChip(tag: tag) {
                            AsyncTask { await viewModel.removeTag(tag) }
                        }
                    }
                }
            }
        }
    }

    private var availableTags: [Tag] {
        viewModel.allTags.filter { tag in
            !viewModel.taskTags.contains(where: { $0.id == tag.id })
        }
    }

    private var addTagPopover: some View {
        VStack(spacing: 12) {
            Text("Add Tag")
                .font(.headline)

            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $newTagType) {
                ForEach(TagType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Cancel") {
                    isAddingTag = false
                    newTagName = ""
                }

                Spacer()

                Button("Add") {
                    AsyncTask {
                        await viewModel.createAndAddTag(name: newTagName, type: newTagType)
                        newTagName = ""
                        isAddingTag = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
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

                if !viewModel.subtasks.isEmpty {
                    Text("\(viewModel.subtasks.filter { $0.status == .completed }.count)/\(viewModel.subtasks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Subtask list
            VStack(spacing: 4) {
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

                // Add subtask
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)

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
                .padding(.vertical, 8)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
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

// MARK: - Tag Chip

struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.caption2)

            Text(tag.displayName)
                .font(.caption.weight(.medium))

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tagColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tagColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(tagColor.opacity(0.3))
        )
        .foregroundColor(tagColor)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var tagColor: Color {
        if let hex = tag.color {
            return Color(hex: hex)
        }
        switch tag.tagType {
        case .tag: return .blue
        case .context: return .purple
        case .area: return .green
        }
    }
}

// MARK: - Flow Layout

struct TaskDetailFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    TaskDetailView(taskId: "preview")
        .frame(width: 500, height: 700)
}
