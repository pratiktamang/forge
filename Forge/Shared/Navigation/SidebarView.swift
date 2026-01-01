import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var perspectiveViewModel = PerspectiveListViewModel()
    @State private var isAddingPerspective = false
    @State private var editingPerspective: Perspective?

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
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { /* Toggle sidebar */ }) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .sheet(isPresented: $isAddingPerspective) {
            PerspectiveEditorSheet()
        }
        .sheet(item: $editingPerspective) { perspective in
            PerspectiveEditorSheet(perspective: perspective)
        }
        .onAppear {
            perspectiveViewModel.startObserving()
        }
        .onDisappear {
            perspectiveViewModel.stopObserving()
        }
    }

    // MARK: - Sections

    private var perspectivesSection: some View {
        Section("Perspectives") {
            sidebarRow(.inbox)
            sidebarRow(.today)
            sidebarRow(.upcoming)
            sidebarRow(.calendar)
            sidebarRow(.flagged)
        }
    }

    @ViewBuilder
    private var customViewsSection: some View {
        Section("Custom Views") {
            ForEach(perspectiveViewModel.perspectives) { perspective in
                perspectiveRow(perspective)
            }
            .onMove { from, to in
                perspectiveViewModel.reorderPerspectives(from: from, to: to)
            }

            addCustomViewButton
        }
    }

    private var projectsSection: some View {
        Section("Projects") {
            ForEach(appState.projects) { project in
                NavigationLink(value: SidebarSection.project(project.id)) {
                    Label(project.title, systemImage: project.icon ?? "folder")
                }
            }

            Button(action: { /* Add project */ }) {
                Label("Add Project", systemImage: "plus")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var planningSection: some View {
        Section("Planning") {
            sidebarRow(.goals)
            sidebarRow(.weeklyReview)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            sidebarRow(.notes)
            sidebarRow(.dailyNote)
        }
    }

    private var trackingSection: some View {
        Section("Tracking") {
            sidebarRow(.habits)
            sidebarRow(.activity)
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.icon)
        }
    }

    @ViewBuilder
    private func perspectiveRow(_ perspective: Perspective) -> some View {
        let colorValue: Color = perspective.color.flatMap { Color(hex: $0) } ?? .accentColor
        NavigationLink(value: SidebarSection.perspective(perspective.id)) {
            Label {
                Text(perspective.title)
            } icon: {
                Image(systemName: perspective.icon)
                    .foregroundColor(colorValue)
            }
        }
        .contextMenu {
            Button("Edit") {
                editingPerspective = perspective
            }
            Button("Delete", role: .destructive) {
                AsyncTask { await perspectiveViewModel.deletePerspective(perspective) }
            }
        }
    }

    private var addCustomViewButton: some View {
        Button(action: { isAddingPerspective = true }) {
            Label("Add Custom View", systemImage: "plus")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SidebarView()
        .environmentObject(AppState())
}
