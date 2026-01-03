import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

private enum TaskProperty: Hashable {
    case dueDate
    case deferDate
    case priority
    case project
    case estimate
}

struct TaskDetailView: View {
    @StateObject private var viewModel: TaskDetailViewModel
    @State private var newSubtaskTitle = ""
    @State private var newTagName = ""
    @State private var isAddingTag = false
    @State private var newTagType: TagType = .tag
    @State private var expandedProperty: TaskProperty?
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

        let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

        VStack(alignment: .leading, spacing: 12) {
            Text("Task Settings")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                TaskPropertyCard(
                    property: .dueDate,
                    icon: "calendar",
                    label: "Due Date",
                    value: dateSummary(task.dueDate),
                    isExpanded: expandedProperty == .dueDate,
                    onToggle: toggleProperty
                )

                TaskPropertyCard(
                    property: .deferDate,
                    icon: "arrow.right.circle",
                    label: "Defer Until",
                    value: dateSummary(task.deferDate),
                    isExpanded: expandedProperty == .deferDate,
                    onToggle: toggleProperty
                )

                TaskPropertyCard(
                    property: .priority,
                    icon: "exclamationmark.circle",
                    label: "Priority",
                    value: prioritySummary(task),
                    isExpanded: expandedProperty == .priority,
                    onToggle: toggleProperty
                )

                TaskPropertyCard(
                    property: .project,
                    icon: "folder",
                    label: "Project",
                    value: projectSummary(task),
                    isExpanded: expandedProperty == .project,
                    onToggle: toggleProperty
                )

                TaskPropertyCard(
                    property: .estimate,
                    icon: "clock",
                    label: "Estimate",
                    value: estimateSummary(task),
                    isExpanded: expandedProperty == .estimate,
                    onToggle: toggleProperty
                )
            }

            if let property = expandedProperty {
                propertyDetail(
                    for: property,
                    task: task,
                    today: today,
                    tomorrow: tomorrow,
                    nextWeek: nextWeek
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func propertyDetail(
        for property: TaskProperty,
        task: Task,
        today: Date,
        tomorrow: Date,
        nextWeek: Date
    ) -> some View {
        switch property {
        case .dueDate:
            PropertyDetailCard(title: "Due Date") {
                TaskDetailFlowLayout(spacing: 8) {
                    PropertyChip(
                        title: "None",
                        isSelected: task.dueDate == nil,
                        action: {
                            viewModel.task?.dueDate = nil
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Today",
                        isSelected: isSameDay(task.dueDate, today),
                        action: {
                            viewModel.task?.dueDate = today
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Tomorrow",
                        isSelected: isSameDay(task.dueDate, tomorrow),
                        action: {
                            viewModel.task?.dueDate = tomorrow
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Next Week",
                        isSelected: isSameDay(task.dueDate, nextWeek),
                        action: {
                            viewModel.task?.dueDate = nextWeek
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Custom",
                        isSelected: false,
                        icon: "calendar.badge.plus",
                        action: {
                            isDuePickerPresented.toggle()
                        }
                    )
                    .popover(isPresented: $isDuePickerPresented) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pick a due date")
                                .font(.headline)

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.task?.dueDate ?? today },
                                    set: {
                                        viewModel.task?.dueDate = $0
                                        AsyncTask { await viewModel.save() }
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                            Button("Clear Due Date") {
                                viewModel.task?.dueDate = nil
                                AsyncTask { await viewModel.save() }
                                isDuePickerPresented = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(width: 280, height: 320)
                    }
                }
            }

        case .deferDate:
            PropertyDetailCard(title: "Defer Until") {
                TaskDetailFlowLayout(spacing: 8) {
                    PropertyChip(
                        title: "None",
                        isSelected: task.deferDate == nil,
                        action: {
                            viewModel.task?.deferDate = nil
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Tomorrow",
                        isSelected: isSameDay(task.deferDate, tomorrow),
                        action: {
                            viewModel.task?.deferDate = tomorrow
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Next Week",
                        isSelected: isSameDay(task.deferDate, nextWeek),
                        action: {
                            viewModel.task?.deferDate = nextWeek
                            AsyncTask { await viewModel.save() }
                        }
                    )

                    PropertyChip(
                        title: "Custom",
                        isSelected: false,
                        icon: "calendar.badge.plus",
                        action: {
                            isDeferPickerPresented.toggle()
                        }
                    )
                    .popover(isPresented: $isDeferPickerPresented) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pick a defer date")
                                .font(.headline)

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.task?.deferDate ?? today },
                                    set: {
                                        viewModel.task?.deferDate = $0
                                        AsyncTask { await viewModel.save() }
                                    }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                            Button("Clear Defer Date") {
                                viewModel.task?.deferDate = nil
                                AsyncTask { await viewModel.save() }
                                isDeferPickerPresented = false
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(width: 280, height: 320)
                    }
                }
            }

        case .priority:
            PropertyDetailCard(title: "Priority") {
                TaskDetailFlowLayout(spacing: 8) {
                    ForEach(Priority.allCases, id: \.self) { priority in
                        PropertyChip(
                            title: priority.displayName,
                            isSelected: viewModel.task?.priority == priority,
                            tint: Color(hex: priority.color),
                            action: {
                                viewModel.task?.priority = priority
                                AsyncTask { await viewModel.save() }
                            }
                        )
                    }
                }
            }

        case .project:
            PropertyDetailCard(title: "Project") {
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
                    Label("Select Project", systemImage: "chevron.down")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                }
                .menuStyle(.borderlessButton)
            }

        case .estimate:
            PropertyDetailCard(title: "Estimate") {
                HStack(spacing: 12) {
                    Stepper(value: Binding(
                        get: { viewModel.task?.estimatedMinutes ?? 0 },
                        set: {
                            viewModel.task?.estimatedMinutes = max(0, $0)
                            AsyncTask { await viewModel.save() }
                        }
                    ), in: 0...1440, step: 5) {
                        Text("\(viewModel.task?.estimatedMinutes ?? 0) min")
                            .font(.callout)
                    }
                    .controlSize(.small)
                }
            }
        }
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

    private func isSameDay(_ date: Date?, _ target: Date) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, inSameDayAs: target)
    }

    private func toggleProperty(_ property: TaskProperty) {
        if expandedProperty == property {
            expandedProperty = nil
        } else {
            expandedProperty = property
        }

        if expandedProperty != .dueDate {
            isDuePickerPresented = false
        }
        if expandedProperty != .deferDate {
            isDeferPickerPresented = false
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

// MARK: - Property Card

private struct PropertyDetailCard<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.1))
                )
        )
    }
}

private struct TaskPropertyCard: View {
    let property: TaskProperty
    let icon: String
    let label: String
    let value: String
    let isExpanded: Bool
    let onToggle: (TaskProperty) -> Void
    @State private var isHovered = false

    var body: some View {
        let highlight = isExpanded || isHovered

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.propertyHighlight)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.propertyHighlight.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(highlight ? AppTheme.propertyHighlight.opacity(isExpanded ? 0.45 : 0.3) : Color.secondary.opacity(0.08),
                                lineWidth: highlight ? 1.5 : 1)
                )
                .shadow(color: highlight ? AppTheme.propertyHighlight.opacity(0.2) : .clear,
                        radius: highlight ? 6 : 0,
                        x: 0,
                        y: highlight ? 3 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .animation(.easeInOut(duration: 0.15), value: highlight)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggle(property)
            }
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

// MARK: - Property Chip

private struct PropertyChip: View {
    let title: String
    let isSelected: Bool
    var tint: Color? = nil
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        let accent = tint ?? .accentColor
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.medium))
            }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? accent.opacity(0.15) : Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? accent : Color.secondary.opacity(0.2))
                )
                .foregroundColor(isSelected ? accent : .primary)
        }
        .buttonStyle(.plain)
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
