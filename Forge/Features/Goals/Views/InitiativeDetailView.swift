import SwiftUI

struct InitiativeDetailView: View {
    @StateObject private var viewModel: InitiativeViewModel
    @EnvironmentObject var appState: AppState
    @State private var isAddingProject = false
    @State private var newProjectTitle = ""

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
                if initiative.startDate != nil || initiative.targetDate != nil {
                    timelineSection(initiative)
                    Divider()
                }

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
                Text("Initiative")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)

                Spacer()

                statusMenu(initiative)
            }

            Text(initiative.title)
                .font(.title.weight(.bold))

            if let description = initiative.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func statusMenu(_ initiative: Initiative) -> some View {
        Menu {
            ForEach(InitiativeStatus.allCases, id: \.self) { status in
                Button(action: {
                    viewModel.initiative?.status = status
                    Task { await viewModel.save() }
                }) {
                    Label(status.displayName, systemImage: statusIcon(status))
                }
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
                if let startDate = initiative.startDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(startDate.formatted(.dateTime.month().day().year()))
                            .font(.subheadline)
                    }
                }

                if initiative.startDate != nil && initiative.targetDate != nil {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                }

                if let targetDate = initiative.targetDate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(targetDate.formatted(.dateTime.month().day().year()))
                            .font(.subheadline)
                            .foregroundColor(targetDate < Date() ? .red : .primary)
                    }
                }

                Spacer()
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
                    Task {
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
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    InitiativeDetailView(initiativeId: "preview")
        .environmentObject(AppState())
}
