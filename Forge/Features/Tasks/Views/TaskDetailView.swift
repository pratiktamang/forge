import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @State private var newTagName = ""
    @State private var isAddingTag = false
    @State private var newTagType: TagType = .tag
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Properties")
                .font(.headline)

            // Quick date buttons
            HStack(spacing: 8) {
                quickDateButton("Today", date: Date()) {
                    viewModel.task?.dueDate = Calendar.current.startOfDay(for: Date())
                    AsyncTask { await viewModel.save() }
                }
                quickDateButton("Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!) {
                    viewModel.task?.dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                    AsyncTask { await viewModel.save() }
                }
                quickDateButton("Next Week", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!) {
                    viewModel.task?.dueDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Calendar.current.startOfDay(for: Date()))
                    AsyncTask { await viewModel.save() }
                }
                if task.dueDate != nil {
                    Button(action: {
                        viewModel.task?.dueDate = nil
                        AsyncTask { await viewModel.save() }
                    }) {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Due Date
                propertyRow(
                    icon: "calendar",
                    label: "Due Date",
                    content: {
                        HStack {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.task?.dueDate ?? Date() },
                                    set: {
                                        viewModel.task?.dueDate = $0
                                        AsyncTask { await viewModel.save() }
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()

                            if task.dueDate != nil {
                                Button(action: {
                                    viewModel.task?.dueDate = nil
                                    AsyncTask { await viewModel.save() }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                )

                // Defer Date
                propertyRow(
                    icon: "arrow.right.circle",
                    label: "Defer Until",
                    content: {
                        HStack {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.task?.deferDate ?? Date() },
                                    set: {
                                        viewModel.task?.deferDate = $0
                                        AsyncTask { await viewModel.save() }
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .labelsHidden()

                            if task.deferDate != nil {
                                Button(action: {
                                    viewModel.task?.deferDate = nil
                                    AsyncTask { await viewModel.save() }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                )

                // Priority
                propertyRow(
                    icon: "exclamationmark.circle",
                    label: "Priority",
                    content: {
                        Picker("", selection: Binding(
                            get: { viewModel.task?.priority ?? .none },
                            set: {
                                viewModel.task?.priority = $0
                                AsyncTask { await viewModel.save() }
                            }
                        )) {
                            ForEach(Priority.allCases, id: \.self) { priority in
                                Text(priority.displayName).tag(priority)
                            }
                        }
                        .labelsHidden()
                    }
                )

                // Project
                propertyRow(
                    icon: "folder",
                    label: "Project",
                    content: {
                        Picker("", selection: Binding(
                            get: { viewModel.task?.projectId },
                            set: {
                                viewModel.task?.projectId = $0
                                AsyncTask { await viewModel.save() }
                            }
                        )) {
                            Text("None").tag(nil as String?)
                            ForEach(viewModel.projects) { project in
                                Text(project.title).tag(project.id as String?)
                            }
                        }
                        .labelsHidden()
                    }
                )

                // Estimated time
                propertyRow(
                    icon: "clock",
                    label: "Estimate",
                    content: {
                        TextField(
                            "minutes",
                            value: Binding(
                                get: { viewModel.task?.estimatedMinutes },
                                set: { viewModel.task?.estimatedMinutes = $0 }
                            ),
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onSubmit {
                            AsyncTask { await viewModel.save() }
                        }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func quickDateButton(_ title: String, date: Date, action: @escaping () -> Void) -> some View {
        let isSelected = viewModel.task?.dueDate != nil &&
                         Calendar.current.isDate(viewModel.task!.dueDate!, inSameDayAs: date)
        Button(action: action) {
            Text(title)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(isSelected ? .accentColor : nil)
    }

    @ViewBuilder
    private func propertyRow<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                content()
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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

                Button(action: { isAddingTag.toggle() }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
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

            // Quick add from existing tags
            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TaskDetailFlowLayout(spacing: 6) {
                        ForEach(availableTags.prefix(10)) { tag in
                            Button(action: {
                                AsyncTask { await viewModel.addTag(tag) }
                            }) {
                                Text(tag.displayName)
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
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
        HStack(spacing: 4) {
            Text(tag.displayName)
                .font(.caption)

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tagColor.opacity(0.15))
        .foregroundColor(tagColor)
        .cornerRadius(4)
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
