import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

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
            case .calendar:
                CalendarView()
            case .project(let projectId):
                ProjectContentView(projectId: projectId)
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

// MARK: - Project Content View

struct ProjectContentView: View {
    let projectId: String
    @State private var viewMode: ViewMode = .list

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case board = "Board"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .board: return "rectangle.3.group"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // View mode picker
            HStack {
                Spacer()
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            switch viewMode {
            case .list:
                TaskListView(filter: .project(projectId))
            case .board:
                ProjectBoardView(projectId: projectId)
            }
        }
    }
}

// MARK: - Project Board View

struct ProjectBoardView: View {
    let projectId: String
    @State private var boardId: String?

    var body: some View {
        Group {
            if let boardId = boardId {
                BoardView(boardId: boardId)
            } else {
                VStack(spacing: 16) {
                    Text("No board yet")
                        .foregroundColor(.secondary)
                    Button("Create Board") {
                        AsyncTask { await createBoard() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadBoard()
        }
    }

    private func loadBoard() async {
        let repository = BoardRepository()
        if let board = try? await repository.fetchDefaultBoard(projectId: projectId) {
            boardId = board.id
        }
    }

    private func createBoard() async {
        let repository = BoardRepository()
        if let board = try? await repository.createBoardWithDefaultColumns(title: "Project Board", projectId: projectId) {
            boardId = board.id
        }
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
            } else if let habitId = appState.selectedHabitId {
                HabitDetailView(habitId: habitId)
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

// MARK: - Placeholder Views (to be implemented in later phases)

// GoalListView and GoalDetailView are now in Features/Goals/Views/

// NoteListView is now in Features/Notes/Views/NoteListView.swift

struct NoteEditorView: View {
    let noteId: String

    var body: some View {
        NoteEditorViewFull(noteId: noteId)
    }
}

struct DailyNoteView: View {
    var body: some View {
        DailyNoteListView()
    }
}


struct ActivityDashboardView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Activity Tracking")
                .font(.headline)
            Text("Coming in Phase 6")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Activity")
    }
}

struct WeeklyReviewView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Weekly Review")
                .font(.headline)
            Text("Coming in Phase 7")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Weekly Review")
    }
}

struct SettingsView: View {
    @AppStorage("isVimModeEnabled") private var isVimModeEnabled = true

    var body: some View {
        Form {
            Section("Editor") {
                Toggle("Vim Mode", isOn: $isVimModeEnabled)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
