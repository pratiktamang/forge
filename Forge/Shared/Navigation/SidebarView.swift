import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(selection: $appState.selectedSection) {
            // Perspectives
            Section("Perspectives") {
                sidebarRow(.inbox)
                sidebarRow(.today)
                sidebarRow(.upcoming)
                sidebarRow(.calendar)
                sidebarRow(.flagged)
            }

            // Projects
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

            // Goals
            Section("Planning") {
                sidebarRow(.goals)
                sidebarRow(.weeklyReview)
            }

            // Notes
            Section("Notes") {
                sidebarRow(.notes)
                sidebarRow(.dailyNote)
            }

            // Tracking
            Section("Tracking") {
                sidebarRow(.habits)
                sidebarRow(.activity)
            }
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
    }

    @ViewBuilder
    private func sidebarRow(_ section: SidebarSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.icon)
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView()
        .environmentObject(AppState())
}
