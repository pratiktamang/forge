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

    @ViewBuilder
    private var projectsSection: some View {
        if !appState.projects.isEmpty {
            Section("Projects") {
                ForEach(appState.projects) { project in
                    Label(project.title, systemImage: project.icon ?? "folder")
                        .tag(SidebarSection.project(project.id))
                }
            }
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

    private func sidebarRow(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.icon)
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
