import SwiftUI

struct MainNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            ContentListView()
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appState.showCommandPalette) {
            CommandPaletteView()
        }
        .sheet(isPresented: $appState.showQuickCapture) {
            QuickCaptureView()
        }
    }
}

// MARK: - Content List View

struct ContentListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .inbox:
                TaskListView(filter: .inbox)
            case .today:
                TaskListView(filter: .today)
            case .upcoming:
                TaskListView(filter: .upcoming)
            case .flagged:
                TaskListView(filter: .flagged)
            case .project(let projectId):
                TaskListView(filter: .project(projectId))
            case .goals:
                GoalListView()
            case .notes:
                NoteListView()
            case .dailyNote:
                DailyNoteView()
            case .habits:
                HabitListView()
            case .activity:
                ActivityDashboardView()
            case .weeklyReview:
                WeeklyReviewView()
            }
        }
        .frame(minWidth: 300)
    }
}

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let taskId = appState.selectedTaskId {
                TaskDetailView(taskId: taskId)
            } else if let noteId = appState.selectedNoteId {
                NoteEditorView(noteId: noteId)
            } else if let goalId = appState.selectedGoalId {
                GoalDetailView(goalId: goalId)
            } else {
                EmptyDetailView()
            }
        }
        .frame(minWidth: 400)
    }
}

// MARK: - Empty State

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an item")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Choose a task, note, or goal from the list to view details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Placeholder Views

struct TaskListView: View {
    enum Filter {
        case inbox, today, upcoming, flagged, project(String)
    }

    let filter: Filter

    var body: some View {
        List {
            Text("Task list for \(filterName)")
                .foregroundColor(.secondary)
        }
        .navigationTitle(filterName)
    }

    private var filterName: String {
        switch filter {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .flagged: return "Flagged"
        case .project: return "Project"
        }
    }
}

struct TaskDetailView: View {
    let taskId: String

    var body: some View {
        Text("Task Detail: \(taskId)")
    }
}

struct GoalListView: View {
    var body: some View {
        List {
            Text("Goals")
        }
        .navigationTitle("Goals")
    }
}

struct GoalDetailView: View {
    let goalId: String

    var body: some View {
        Text("Goal Detail: \(goalId)")
    }
}

struct NoteListView: View {
    var body: some View {
        List {
            Text("Notes")
        }
        .navigationTitle("Notes")
    }
}

struct NoteEditorView: View {
    let noteId: String

    var body: some View {
        Text("Note Editor: \(noteId)")
    }
}

struct DailyNoteView: View {
    var body: some View {
        Text("Daily Note")
            .navigationTitle("Daily Note")
    }
}

struct HabitListView: View {
    var body: some View {
        List {
            Text("Habits")
        }
        .navigationTitle("Habits")
    }
}

struct ActivityDashboardView: View {
    var body: some View {
        Text("Activity Dashboard")
            .navigationTitle("Activity")
    }
}

struct WeeklyReviewView: View {
    var body: some View {
        Text("Weekly Review")
            .navigationTitle("Weekly Review")
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .frame(width: 400, height: 300)
    }
}
