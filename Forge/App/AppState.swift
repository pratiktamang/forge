import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Navigation

    @Published var selectedSection: SidebarSection = .inbox
    @Published var selectedTaskId: String?
    @Published var selectedNoteId: String?
    @Published var selectedProjectId: String?
    @Published var selectedGoalId: String?
    @Published var selectedHabitId: String?

    // MARK: - UI State

    @Published var showCommandPalette = false
    @Published var showQuickCapture = false
    @Published var searchQuery = ""
    @Published var isVimModeEnabled = true

    // MARK: - Data

    @Published var projects: [Project] = []
    @Published var tags: [Tag] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .showCommandPalette)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showCommandPalette = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .quickCapture)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showQuickCapture = true
            }
            .store(in: &cancellables)
    }
}

// MARK: - Sidebar Sections

enum SidebarSection: Hashable, Identifiable {
    case inbox
    case today
    case upcoming
    case flagged
    case calendar
    case perspective(String)
    case project(String)
    case goals
    case notes
    case dailyNote
    case habits
    case activity
    case weeklyReview

    var id: String {
        switch self {
        case .inbox: return "inbox"
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .flagged: return "flagged"
        case .calendar: return "calendar"
        case .perspective(let id): return "perspective-\(id)"
        case .project(let id): return "project-\(id)"
        case .goals: return "goals"
        case .notes: return "notes"
        case .dailyNote: return "dailyNote"
        case .habits: return "habits"
        case .activity: return "activity"
        case .weeklyReview: return "weeklyReview"
        }
    }

    var title: String {
        switch self {
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .flagged: return "Flagged"
        case .calendar: return "Calendar"
        case .perspective: return "Perspective"
        case .project: return "Project"
        case .goals: return "Goals"
        case .notes: return "Notes"
        case .dailyNote: return "Daily Note"
        case .habits: return "Habits"
        case .activity: return "Activity"
        case .weeklyReview: return "Weekly Review"
        }
    }

    var icon: String {
        switch self {
        case .inbox: return "tray"
        case .today: return "star"
        case .upcoming: return "calendar.badge.clock"
        case .flagged: return "flag"
        case .calendar: return "calendar"
        case .perspective: return "line.3.horizontal.decrease.circle"
        case .project: return "folder"
        case .goals: return "target"
        case .notes: return "doc.text"
        case .dailyNote: return "calendar.day.timeline.left"
        case .habits: return "checkmark.circle"
        case .activity: return "chart.bar"
        case .weeklyReview: return "checkmark.seal"
        }
    }
}
