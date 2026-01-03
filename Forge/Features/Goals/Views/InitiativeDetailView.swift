import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct InitiativeDetailView: View {
    @StateObject private var viewModel: InitiativeViewModel
    @EnvironmentObject var appState: AppState
    @State private var isAddingProject = false
    @State private var newProjectTitle = ""
    @State private var showDeleteConfirmation = false
    @State private var isEditingTitle = false

    init(initiativeId: String) {
        _viewModel = StateObject(wrappedValue: InitiativeViewModel(initiativeId: initiativeId))
    }

    var body: some View {
        Group {
            if let initiative = viewModel.initiative {
                initiativeContent(initiative)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Initiative not found")
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

    @ViewBuilder
    private func initiativeContent(_ initiative: Initiative) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection(initiative)

                Divider()

                // Progress
                progressSection

                Divider()

                // Timeline
                timelineSection(initiative)
                Divider()

                // Description
                descriptionSection(initiative)

                Divider()

                // Projects
                projectsSection

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ initiative: Initiative) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let goalId = initiative.goalId {
                    Button(action: {
                        appState.selectedInitiativeId = nil
                        appState.selectedGoalId = goalId
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption)
                            Text("Back to Goal")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("Initiative")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)

                statusMenu(initiative)
            }

            HStack(spacing: 8) {
                if isEditingTitle {
                    TextField("Initiative title", text: Binding(
                        get: { viewModel.initiative?.title ?? "" },
                        set: { viewModel.initiative?.title = $0 }
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
                    Text(initiative.title)
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

    @ViewBuilder
    private func statusMenu(_ initiative: Initiative) -> some View {
        Menu {
            ForEach(InitiativeStatus.allCases, id: \.self) { status in
                Button(action: {
                    viewModel.initiative?.status = status
                    AsyncTask { await viewModel.save() }
                }) {
                    Label(status.displayName, systemImage: statusIcon(status))
                }
            }

            Divider()

            Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                Label("Delete Initiative", systemImage: "trash")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: statusIcon(initiative.status))
                Text(initiative.status.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(initiative.status).opacity(0.1))
            .foregroundColor(statusColor(initiative.status))
            .cornerRadius(4)
        }
        .menuStyle(.borderlessButton)
        .confirmationDialog(
            "Delete Initiative",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                AsyncTask {
                    if await viewModel.delete() {
                        appState.selectedInitiativeId = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(initiative.title)\"? This action cannot be undone.")
        }
    }

    private func statusIcon(_ status: InitiativeStatus) -> String {
        switch status {
        case .active: return "circle"
        case .onHold: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .archived: return "archivebox"
        }
    }

    private func statusColor(_ status: InitiativeStatus) -> Color {
        switch status {
        case .active: return .blue
        case .onHold: return .orange
        case .completed: return .green
        case .archived: return .secondary
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressSection: some View {
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

            Text("\(viewModel.projects.filter { $0.status == .completed }.count) of \(viewModel.projects.count) projects completed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Timeline

    @ViewBuilder
    private func timelineSection(_ initiative: Initiative) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.initiative?.startDate ?? Date() },
                                set: { viewModel.initiative?.startDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .onChange(of: viewModel.initiative?.startDate) { _, _ in
                            AsyncTask { await viewModel.save() }
                        }

                        if viewModel.initiative?.startDate != nil {
                            Button(action: {
                                viewModel.initiative?.startDate = nil
                                AsyncTask { await viewModel.save() }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { viewModel.initiative?.targetDate ?? Date() },
                                set: { viewModel.initiative?.targetDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .onChange(of: viewModel.initiative?.targetDate) { _, _ in
                            AsyncTask { await viewModel.save() }
                        }

                        if viewModel.initiative?.targetDate != nil {
                            Button(action: {
                                viewModel.initiative?.targetDate = nil
                                AsyncTask { await viewModel.save() }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                if let targetDate = initiative.targetDate {
                    if targetDate < Date() && initiative.status == .active {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionSection(_ initiative: Initiative) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)

            TextEditor(text: Binding(
                get: { viewModel.initiative?.description ?? "" },
                set: { viewModel.initiative?.description = $0.isEmpty ? nil : $0 }
            ))
            .font(.body)
            .frame(minHeight: 80)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Projects

    @ViewBuilder
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects")
                    .font(.headline)

                Spacer()

                Button(action: { isAddingProject = true }) {
                    Label("Add Project", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $isAddingProject) {
                    addProjectPopover
                }
            }

            if viewModel.projects.isEmpty {
                Text("No projects yet. Break down this initiative into concrete projects.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.projects) { project in
                    ProjectRow(project: project)
                        .onTapGesture {
                            appState.selectedSection = .project(project.id)
                        }
                }
            }
        }
    }

    private var addProjectPopover: some View {
        VStack(spacing: 12) {
            Text("New Project")
                .font(.headline)

            TextField("Project title", text: $newProjectTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isAddingProject = false
                    newProjectTitle = ""
                }

                Spacer()

                Button("Create") {
                    AsyncTask {
                        await viewModel.createProject(title: newProjectTitle)
                        newProjectTitle = ""
                        isAddingProject = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newProjectTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    @State private var isHovered = false

    var body: some View {
        HStack {
            Image(systemName: project.icon ?? "folder")
                .foregroundColor(project.color != nil ? Color(hex: project.color!) : .accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.subheadline.weight(.medium))

                Text(project.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if project.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

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
}

// MARK: - Preview

#Preview {
    InitiativeDetailView(initiativeId: "preview")
        .environmentObject(AppState())
}
