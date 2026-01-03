import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var perspectiveViewModel = PerspectiveListViewModel()
    @StateObject private var projectViewModel = ProjectListViewModel()
    @State private var isAddingPerspective = false
    @State private var editingPerspective: Perspective?
    @State private var isAddingProject = false
    @State private var newProjectTitle = ""
    @State private var editingProject: Project? = nil
    private let rowFont = Font.system(size: 13, weight: .medium, design: .rounded)

    var body: some View {
        List(selection: $appState.selectedSection) {
            perspectivesSection
            customViewsSection
            projectsSection
            planningSection
            notesSection
            trackingSection
        }
        .listStyle(.sidebar)
        .listSectionSeparator(.hidden)
        .scrollContentBackground(.hidden)
        .background(AppTheme.sidebarBackground)
        .listRowBackground(AppTheme.sidebarRowBackground)
        .frame(minWidth: 230)
        .sheet(isPresented: $isAddingPerspective) {
            PerspectiveEditorSheet()
        }
        .sheet(item: $editingPerspective) { perspective in
            PerspectiveEditorSheet(perspective: perspective)
        }
        .alert("New Project", isPresented: $isAddingProject) {
            TextField("Project name", text: $newProjectTitle)
            Button("Cancel", role: .cancel) {
                newProjectTitle = ""
            }
            Button("Create") {
                AsyncTask {
                    await projectViewModel.createProject(title: newProjectTitle)
                    newProjectTitle = ""
                }
            }
        }
        .sheet(item: $editingProject) { project in
            ProjectEditorSheet(project: project)
        }
        .onAppear {
            perspectiveViewModel.startObserving()
            projectViewModel.startObserving()
        }
        .onDisappear {
            perspectiveViewModel.stopObserving()
            projectViewModel.stopObserving()
        }
    }

    // MARK: - Sections

    private var perspectivesSection: some View {
        Section {
            sidebarRow(.inbox)
            sidebarRow(.today)
            sidebarRow(.upcoming)
            sidebarRow(.calendar)
            sidebarRow(.flagged)
        } header: {
            SidebarSectionHeader(title: "Perspectives")
        }
    }

    @ViewBuilder
    private var customViewsSection: some View {
        Section {
            ForEach(perspectiveViewModel.perspectives) { perspective in
                perspectiveRow(perspective)
            }
            .onMove { from, to in
                perspectiveViewModel.reorderPerspectives(from: from, to: to)
            }

            addCustomViewButton
        } header: {
            SidebarSectionHeader(title: "Custom Views")
        }
    }

    @ViewBuilder
    private var projectsSection: some View {
        Section {
            if projectViewModel.projectsWithCounts.isEmpty {
                Text("Organize work into projects")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.vertical, 4)
            }

            ForEach(projectViewModel.projectsWithCounts, id: \.project.id) { item in
                projectRow(item)
            }

            Button(action: { isAddingProject = true }) {
                Label("Add Project", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.accentShadow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.sidebarHeaderBackground.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
        } header: {
            SidebarSectionHeader(title: "Projects")
        }
    }

    @ViewBuilder
    private func projectRow(_ item: ProjectRepository.ProjectWithTaskCount) -> some View {
        let project = item.project
        let iconColor: Color = project.color.flatMap { Color(hex: $0) } ?? .accentColor

        HStack {
            Image(systemName: project.icon ?? "folder")
                .foregroundColor(iconColor)
            Text(project.title)
                .font(rowFont)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if item.taskCount > 0 {
                Text("\(item.taskCount)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.sidebarHeaderBackground.opacity(0.6))
                    .cornerRadius(4)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .tag(SidebarSection.project(project.id))
        .contextMenu {
            Button("Edit") {
                editingProject = project
            }

            Divider()

            Button("Duplicate") {
                AsyncTask { await projectViewModel.duplicateProject(project) }
            }

            Button("Archive") {
                AsyncTask {
                    var archived = project
                    archived.status = .archived
                    await projectViewModel.updateProject(archived)
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                AsyncTask { await projectViewModel.deleteProject(project) }
            }
        }
    }

    private var planningSection: some View {
        Section {
            sidebarRow(.goals)
            sidebarRow(.weeklyReview)
        } header: {
            SidebarSectionHeader(title: "Planning")
        }
    }

    private var notesSection: some View {
        Section {
            sidebarRow(.notes)
            sidebarRow(.dailyNote)
        } header: {
            SidebarSectionHeader(title: "Notes")
        }
    }

    private var trackingSection: some View {
        Section {
            sidebarRow(.habits)
            sidebarRow(.activity)
        } header: {
            SidebarSectionHeader(title: "Tracking")
        }
    }

    // MARK: - Row Builders

    private func sidebarRow(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.icon)
            .font(rowFont)
            .foregroundColor(AppTheme.textPrimary)
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .tag(section)
    }

    @ViewBuilder
    private func perspectiveRow(_ perspective: Perspective) -> some View {
        let colorValue: Color = perspective.color.flatMap { Color(hex: $0) } ?? .accentColor
        Label {
            Text(perspective.title)
        } icon: {
            Image(systemName: perspective.icon)
                .foregroundColor(colorValue)
        }
        .tag(SidebarSection.perspective(perspective.id))
        .font(rowFont)
        .foregroundColor(AppTheme.textPrimary)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        .contextMenu {
            Button("Edit") {
                editingPerspective = perspective
            }
            Button("Delete", role: .destructive) {
                AsyncTask { await perspectiveViewModel.deletePerspective(perspective) }
            }
        }
    }

    private struct SidebarSectionHeader: View {
        let title: String

        var body: some View {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .kerning(0.8)
                .foregroundColor(AppTheme.sidebarHeaderText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.sidebarHeaderBackground)
                )
                .padding(.horizontal, 4)
                .padding(.top, 8)
        }
    }

    private var addCustomViewButton: some View {
        Button(action: { isAddingPerspective = true }) {
            Label("Add Custom View", systemImage: "plus")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.accentShadow)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.sidebarHeaderBackground.opacity(0.8))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SidebarView()
        .environmentObject(AppState())
}
