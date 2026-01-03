import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct GoalDetailView: View {
    @StateObject private var viewModel: GoalDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var isEditingTitle = false
    @State private var isAddingInitiative = false
    @State private var isAddingQuarterlyGoal = false
    @State private var newInitiativeTitle = ""
    @State private var newQuarterlyGoalTitle = ""
    @State private var selectedQuarter: Int = 1
    @State private var showDeleteConfirmation = false

    init(goalId: String) {
        _viewModel = StateObject(wrappedValue: GoalDetailViewModel(goalId: goalId))
    }

    var body: some View {
        Group {
            if let goal = viewModel.goal {
                goalDetailContent(goal)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Goal not found")
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

    // MARK: - Goal Detail Content

    @ViewBuilder
    private func goalDetailContent(_ goal: Goal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection(goal)

                Divider()

                // Target Date
                targetDateSection(goal)

                Divider()

                // Progress
                progressSection(goal)

                Divider()

                // Description
                descriptionSection(goal)
                Divider()

                // Child Goals (for yearly goals)
                if goal.goalType == .yearly {
                    childGoalsSection
                    Divider()
                }

                // Initiatives
                initiativesSection

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Type badge
                Text(goal.goalType == .yearly ? "Yearly Goal" : "Q\(goal.quarter ?? 0) Goal")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)

                Text(goal.displayPeriod)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                statusMenu(goal)
            }

            // Title
            HStack(spacing: 8) {
                if isEditingTitle {
                    TextField("Goal title", text: Binding(
                        get: { viewModel.goal?.title ?? "" },
                        set: { viewModel.goal?.title = $0 }
                    ))
                    .font(.title.weight(.bold))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        isEditingTitle = false
                        AsyncTask { await viewModel.save() }
                    }

                    Button(action: {
                        isEditingTitle = false
                        AsyncTask { await viewModel.save() }
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(goal.title)
                        .font(.title.weight(.bold))

                    Button(action: { isEditingTitle = true }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(0.6)
                }
            }
        }
    }

    // MARK: - Target Date Section

    @ViewBuilder
    private func targetDateSection(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Date")
                .font(.headline)

            HStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.goal?.targetDate ?? Date() },
                        set: { viewModel.goal?.targetDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                .onChange(of: viewModel.goal?.targetDate) { _, _ in
                    AsyncTask { await viewModel.save() }
                }

                if viewModel.goal?.targetDate != nil {
                    Button(action: {
                        viewModel.goal?.targetDate = nil
                        AsyncTask { await viewModel.save() }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if let targetDate = goal.targetDate {
                    if targetDate < Date() && goal.status == .active {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text(relativeDateString(targetDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)

        guard let days = components.day else { return "" }

        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days > 0 && days <= 7 {
            return "Due in \(days) days"
        } else if days > 7 {
            let weeks = days / 7
            return weeks == 1 ? "Due in 1 week" : "Due in \(weeks) weeks"
        } else {
            return ""
        }
    }

    @ViewBuilder
    private func statusMenu(_ goal: Goal) -> some View {
        Menu {
            Button(action: {
                AsyncTask {
                    viewModel.goal?.status = .active
                    await viewModel.save()
                }
            }) {
                Label("Active", systemImage: "circle")
            }

            Button(action: {
                AsyncTask {
                    viewModel.goal?.status = .completed
                    viewModel.goal?.progress = 1.0
                    await viewModel.save()
                }
            }) {
                Label("Completed", systemImage: "checkmark.circle")
            }

            Button(action: {
                AsyncTask {
                    viewModel.goal?.status = .archived
                    await viewModel.save()
                }
            }) {
                Label("Archived", systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete Goal", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: statusIcon(goal.status))
                Text(goal.status.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(goal.status).opacity(0.1))
            .foregroundColor(statusColor(goal.status))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .confirmationDialog(
            "Delete Goal",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                AsyncTask {
                    if await viewModel.delete() {
                        appState.selectedGoalId = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(goal.title)\"? This action cannot be undone.")
        }
    }

    private func statusIcon(_ status: GoalStatus) -> String {
        switch status {
        case .active: return "circle"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox"
        }
    }

    private func statusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .active: return .blue
        case .completed: return .green
        case .archived: return .secondary
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)

                Spacer()

                Text("\(Int(viewModel.progress * 100))%")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.accentColor)
            }

            ProgressView(value: viewModel.progress)
                .scaleEffect(y: 2)
                .tint(progressColor(viewModel.progress))

            // Manual progress slider for leaf goals
            if viewModel.childGoals.isEmpty && viewModel.initiatives.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjust manually:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Slider(
                        value: Binding(
                            get: { viewModel.goal?.progress ?? 0 },
                            set: { viewModel.goal?.progress = $0 }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                    .onChange(of: viewModel.goal?.progress) { _, _ in
                        AsyncTask { await viewModel.save() }
                    }
                }
            }
        }
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.5 {
            return .blue
        } else if progress >= 0.25 {
            return .orange
        } else {
            return .secondary
        }
    }

    // MARK: - Description Section

    @ViewBuilder
    private func descriptionSection(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)

            TextEditor(text: Binding(
                get: { viewModel.goal?.description ?? "" },
                set: { viewModel.goal?.description = $0.isEmpty ? nil : $0 }
            ))
            .font(.body)
            .frame(minHeight: 80)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .onChange(of: viewModel.goal?.description) { _, _ in
                // Debounce save
            }
        }
    }

    // MARK: - Child Goals Section

    @ViewBuilder
    private var childGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quarterly Goals")
                    .font(.headline)

                Spacer()

                Button(action: { isAddingQuarterlyGoal = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $isAddingQuarterlyGoal) {
                    addQuarterlyGoalPopover
                }
            }

            if viewModel.childGoals.isEmpty {
                Text("No quarterly goals linked yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                ForEach(viewModel.childGoals) { childGoal in
                    Button(action: { appState.selectedGoalId = childGoal.id }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Q\(childGoal.quarter ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(childGoal.title)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }

                            Spacer()

                            Text("\(Int(childGoal.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ProgressView(value: childGoal.progress)
                                .frame(width: 60)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addQuarterlyGoalPopover: some View {
        VStack(spacing: 12) {
            Text("New Quarterly Goal")
                .font(.headline)

            TextField("Goal title", text: $newQuarterlyGoalTitle)
                .textFieldStyle(.roundedBorder)

            if let goal = viewModel.goal {
                Picker("Quarter", selection: $selectedQuarter) {
                    ForEach(1...4, id: \.self) { q in
                        Text("Q\(q) \(goal.year)").tag(q)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Button("Cancel") {
                    isAddingQuarterlyGoal = false
                    newQuarterlyGoalTitle = ""
                }

                Spacer()

                Button("Add") {
                    AsyncTask {
                        await viewModel.addQuarterlyGoal(title: newQuarterlyGoalTitle, quarter: selectedQuarter)
                        newQuarterlyGoalTitle = ""
                        isAddingQuarterlyGoal = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newQuarterlyGoalTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Initiatives Section

    @ViewBuilder
    private var initiativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Initiatives")
                    .font(.headline)

                Spacer()

                Button(action: { isAddingInitiative = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $isAddingInitiative) {
                    addInitiativePopover
                }
            }

            if viewModel.initiatives.isEmpty {
                Text("No initiatives yet. Add major efforts that help achieve this goal.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                ForEach(viewModel.initiatives) { initiative in
                    Button(action: {
                        appState.selectedGoalId = nil
                        appState.selectedInitiativeId = initiative.id
                    }) {
                        InitiativeRow(initiative: initiative)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addInitiativePopover: some View {
        VStack(spacing: 12) {
            Text("New Initiative")
                .font(.headline)

            TextField("Initiative title", text: $newInitiativeTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isAddingInitiative = false
                    newInitiativeTitle = ""
                }

                Spacer()

                Button("Add") {
                    AsyncTask {
                        await viewModel.addInitiative(title: newInitiativeTitle, description: nil)
                        newInitiativeTitle = ""
                        isAddingInitiative = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newInitiativeTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Initiative Row

struct InitiativeRow: View {
    let initiative: Initiative
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(initiative.title)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Label(initiative.status.displayName, systemImage: statusIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let targetDate = initiative.targetDate {
                        Label(targetDate.formatted(.dateTime.month().day()), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(targetDate < Date() && initiative.status == .active ? .red : .secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(isHovered ? .accentColor : .secondary)
        }
        .padding(12)
        .background(isHovered ? Color.accentColor.opacity(0.05) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var statusIcon: String {
        switch initiative.status {
        case .active: return "circle"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox"
        }
    }
}

// MARK: - Preview

#Preview {
    GoalDetailView(goalId: "preview")
}
