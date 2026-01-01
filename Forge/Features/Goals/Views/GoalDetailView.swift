import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct GoalDetailView: View {
    @StateObject private var viewModel: GoalDetailViewModel
    @State private var isEditingTitle = false
    @State private var isAddingInitiative = false
    @State private var isAddingQuarterlyGoal = false
    @State private var newInitiativeTitle = ""

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

                // Progress
                progressSection(goal)

                Divider()

                // Description
                if goal.description != nil || true {
                    descriptionSection(goal)
                    Divider()
                }

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
            } else {
                Text(goal.title)
                    .font(.title.weight(.bold))
                    .onTapGesture(count: 2) {
                        isEditingTitle = true
                    }
            }
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
            }

            if viewModel.childGoals.isEmpty {
                Text("No quarterly goals linked to this yearly goal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.childGoals) { childGoal in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Q\(childGoal.quarter ?? 0)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(childGoal.title)
                                .font(.subheadline)
                        }

                        Spacer()

                        Text("\(Int(childGoal.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ProgressView(value: childGoal.progress)
                            .frame(width: 60)
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
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
                Text("No initiatives yet. Initiatives are major efforts that help achieve this goal.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.initiatives) { initiative in
                    InitiativeRow(initiative: initiative)
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
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
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
