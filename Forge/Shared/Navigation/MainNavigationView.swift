import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct MainNavigationView: View {
    @EnvironmentObject var appState: AppState

    private var dynamicTypeSize: DynamicTypeSize {
        switch appState.textScale {
        case ..<0.8: return .xSmall
        case 0.8..<0.9: return .small
        case 0.9..<1.0: return .medium
        case 1.0..<1.1: return .large
        case 1.1..<1.2: return .xLarge
        case 1.2..<1.3: return .xxLarge
        default: return .xxxLarge
        }
    }

    private var hasDetailSelection: Bool {
        appState.selectedTaskId != nil ||
        appState.selectedNoteId != nil ||
        appState.selectedGoalId != nil ||
        appState.selectedInitiativeId != nil ||
        appState.selectedHabitId != nil
    }

    private var isNoteSelected: Bool {
        appState.selectedNoteId != nil
    }

    private var listWidthFraction: CGFloat {
        isNoteSelected ? 0.5 : 0.3
    }

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ContentListView()
                        .frame(width: hasDetailSelection && !appState.isInBoardMode
                               ? geometry.size.width * listWidthFraction
                               : nil)

                    if hasDetailSelection && !appState.isInBoardMode {
                        Divider()
                        DetailView()
                            .frame(maxWidth: .infinity)
                            .transition(.opacity.animation(.easeOut(duration: 0.2)))
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: hasDetailSelection)
                .animation(.easeInOut(duration: 0.25), value: isNoteSelected)
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .padding(.vertical, 12)
            .padding(.trailing, 12)
            .padding(.leading, 14)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .background(AppTheme.windowBackground)
        .environment(\.textScale, appState.textScale)
        .environment(\.dynamicTypeSize, dynamicTypeSize)
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
            case .dashboard:
                DashboardView()
            case .perspective(let perspectiveId):
                PerspectiveTaskListView(perspectiveId: perspectiveId)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedSection)
        .onChange(of: appState.selectedSection) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                // Clear detail selections when switching sections
                appState.selectedTaskId = nil
                appState.selectedNoteId = nil
                appState.selectedGoalId = nil
                appState.selectedInitiativeId = nil
                appState.selectedHabitId = nil
                appState.isInBoardMode = false
            }
        }
    }
}

// MARK: - Project Content View

struct ProjectContentView: View {
    let projectId: String
    @EnvironmentObject var appState: AppState
    @State private var viewMode: ViewMode = .list
    @State private var project: Project?
    @State private var taskCount: Int = 0
    @State private var completedCount: Int = 0
    @State private var isEditingProject = false

    private let repository = ProjectRepository()

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
            // Project header
            if let project = project {
                projectHeader(project)
            }

            Divider()

            // Content
            switch viewMode {
            case .list:
                TaskListView(filter: .project(projectId))
            case .board:
                ProjectBoardView(projectId: projectId)
            }
        }
        .task {
            await loadProject()
        }
        .sheet(isPresented: $isEditingProject) {
            if let project = project {
                ProjectEditorSheet(project: project)
            }
        }
        .onChange(of: isEditingProject) { _, isEditing in
            if !isEditing {
                AsyncTask { await loadProject() }
            }
        }
        .onChange(of: viewMode) { _, mode in
            appState.isInBoardMode = (mode == .board)
        }
        .onDisappear {
            appState.isInBoardMode = false
        }
    }

    @ViewBuilder
    private func projectHeader(_ project: Project) -> some View {
        let iconColor: Color = project.color.flatMap { Color(hex: $0) } ?? AppTheme.accent
        let totalTasks = taskCount + completedCount
        let progress: Double = totalTasks > 0 ? Double(completedCount) / Double(totalTasks) : 0

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Project icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: project.icon ?? "folder")
                        .font(.title3)
                        .foregroundColor(iconColor)
                }

                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.headline)
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Stats
                if totalTasks > 0 {
                    HStack(spacing: 16) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(completedCount)/\(totalTasks)")
                                .font(.headline)
                                .foregroundColor(iconColor)
                            Text("completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(iconColor.opacity(0.2), lineWidth: 4)
                                .frame(width: 32, height: 32)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(iconColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }

                // View mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 80)

                // Settings button
                Button(action: { isEditingProject = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func loadProject() async {
        project = try? await repository.fetch(id: projectId)
        if let counts = try? await repository.fetchProjectWithTaskCount(id: projectId) {
            taskCount = counts.taskCount
            completedCount = counts.completedCount
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
                    .id(taskId)
            } else if let noteId = appState.selectedNoteId {
                NoteEditorView(noteId: noteId)
            } else if let goalId = appState.selectedGoalId {
                GoalDetailView(goalId: goalId)
            } else if let initiativeId = appState.selectedInitiativeId {
                InitiativeDetailView(initiativeId: initiativeId)
            } else if let habitId = appState.selectedHabitId {
                HabitDetailView(habitId: habitId)
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedTaskId)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedNoteId)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedGoalId)
        .animation(.easeInOut(duration: 0.2), value: appState.selectedHabitId)
    }
}

// MARK: - Empty State

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.accent)

            Text("Select an item")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("Choose a task, note, or goal from the list to view details")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
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


// ActivityDashboardView is now in Features/Activity/Views/ActivityDashboardView.swift

// WeeklyReviewView is now in Features/WeeklyReview/Views/WeeklyReviewView.swift

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
