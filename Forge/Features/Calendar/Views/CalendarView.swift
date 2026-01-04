import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var appState: AppState

    private let calendar = Calendar.current
    private let badgeWidth: CGFloat = 96

    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    monthNavigator

                    if !ongoingTasks.isEmpty {
                        ongoingSection
                    }

                    timelineSection
                        .padding(.top, 8)

                    footerControls
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
            }
            .background(AppTheme.contentBackground)
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Today") {
                    viewModel.goToToday()
                }
                .disabled(viewModel.isCurrentMonth)
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.monthYearString)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private var subtitle: String {
        if ongoingTasks.isEmpty {
            return "Every day has room for intention."
        }
        return "\(ongoingTasks.count) ongoing \(ongoingTasks.count == 1 ? "task" : "tasks") waiting for you."
    }

    // MARK: - Navigation Chips

    private var monthNavigator: some View {
        HStack(spacing: 12) {
            MonthChipButton(
                title: "Show Previous Days",
                systemImage: "chevron.up",
                action: viewModel.previousMonth
            )

            Spacer()

            MonthChipButton(
                title: "Jump to Today",
                systemImage: "dot.scope",
                action: viewModel.goToToday
            )

            MonthChipButton(
                title: "Show Next Days",
                systemImage: "chevron.down",
                action: viewModel.nextMonth
            )
        }
    }

    // MARK: - Ongoing Section

    private var ongoingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ongoing", systemImage: "infinity")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            LazyVStack(spacing: 10) {
                ForEach(ongoingTasks.prefix(3), id: \.id) { task in
                    TaskRowView(
                        task: task,
                        isSelected: appState.selectedTaskId == task.id,
                        style: .minimal,
                        onToggleComplete: {
                            AsyncTask { await viewModel.toggleComplete(task) }
                        },
                        onToggleFlag: {
                            AsyncTask { await viewModel.toggleFlag(task) }
                        }
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appState.selectedTaskId = task.id
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.cardBackground.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(AppTheme.cardBorder.opacity(0.8), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(AppTheme.cardBorder.opacity(0.5))
                .frame(width: 1.2)
                .padding(.leading, badgeWidth / 2)
                .padding(.top, 20)
                .padding(.bottom, 20)

            LazyVStack(spacing: 28) {
                ForEach(timelineDays, id: \.self) { date in
                    let normalized = calendar.startOfDay(for: date)
                    let tasks = viewModel.tasksByDate[normalized]?.sorted(by: taskComparator) ?? []
                    let events = viewModel.eventsByDate[normalized]?.sorted(by: { $0.startDate < $1.startDate }) ?? []

                    TimelineDayCard(
                        date: date,
                        tasks: tasks,
                        events: events,
                        relativeLabel: relativeLabel(for: date),
                        isToday: calendar.isDateInToday(date),
                        selectedTaskId: appState.selectedTaskId,
                        badgeWidth: badgeWidth,
                        onCreateTask: { title in
                            AsyncTask { await viewModel.createTask(title: title, on: date) }
                        },
                        onToggleComplete: { task in
                            AsyncTask { await viewModel.toggleComplete(task) }
                        },
                        onToggleFlag: { task in
                            AsyncTask { await viewModel.toggleFlag(task) }
                        },
                        onSelectTask: { task in
                            withAnimation(.easeInOut(duration: 0.16)) {
                                appState.selectedTaskId = task.id
                            }
                        }
                    )
                }
            }
        }
    }

    private func taskComparator(lhs: Task, rhs: Task) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (l?, r?):
            if l == r {
                return lhs.title < rhs.title
            }
            return l < r
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.title < rhs.title
        }
    }

    private var timelineDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: viewModel.displayedMonth) else {
            return []
        }

        var dates: [Date] = []
        var current = interval.start
        while current < interval.end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    private func relativeLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var ongoingTasks: [Task] {
        let today = calendar.startOfDay(for: Date())
        return viewModel.tasksForMonth
            .filter { task in
                guard let due = task.dueDate else { return false }
                return due < today && task.status != .completed
            }
            .sorted { ($0.dueDate ?? today) > ($1.dueDate ?? today) }
    }

    // MARK: - Footer

    private var footerControls: some View {
        HStack {
            Button {
                viewModel.previousMonth()
            } label: {
                Label("Show Previous Months", systemImage: "arrow.uturn.up")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.cardBackground.opacity(0.6))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppTheme.cardBorder.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.nextMonth()
            } label: {
                Label("Show Next Months", systemImage: "arrow.uturn.down")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.cardBackground.opacity(0.6))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppTheme.cardBorder.opacity(0.7), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Timeline Card

private struct TimelineDayCard: View {
    let date: Date
    let tasks: [Task]
    let events: [CalendarEvent]
    let relativeLabel: String
    let isToday: Bool
    let selectedTaskId: String?
    let badgeWidth: CGFloat
    let onCreateTask: (String) -> Void
    let onToggleComplete: (Task) -> Void
    let onToggleFlag: (Task) -> Void
    let onSelectTask: (Task) -> Void

    @State private var newTaskTitle = ""
    @FocusState private var isAddingTask: Bool

    private let calendar = Calendar.current

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            DayBadge(
                date: date,
                relativeLabel: relativeLabel,
                isToday: isToday,
                width: badgeWidth
            )

            VStack(alignment: .leading, spacing: 20) {
                eventsSection

                Divider()
                    .overlay(AppTheme.cardBorder.opacity(0.5))

                tasksSection

                quickAddBar
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.cardBackground.opacity(0.9),
                                AppTheme.cardBackground.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                isToday ? AppTheme.selectionBorder.opacity(0.8) : AppTheme.cardBorder.opacity(0.7),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Events", systemImage: "calendar")

            if events.isEmpty {
                Text("No meetings on the books.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.metadataText)
            } else {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Tasks", systemImage: "checkmark.seal")

            if tasks.isEmpty {
                taskEmptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            isSelected: selectedTaskId == task.id,
                            style: .minimal,
                            onToggleComplete: { onToggleComplete(task) },
                            onToggleFlag: { onToggleFlag(task) }
                        )
                        .onTapGesture {
                            onSelectTask(task)
                        }
                    }
                }
            }
        }
    }

    private var taskEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No plans yet.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)

            Text("Drop intentions for \(dayString).")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.metadataText)
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.system(size: 18, weight: .semibold))

            TextField("Add task for \(dayString)...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .focused($isAddingTask)
                .onSubmit(commitTask)

            if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: commitTask) {
                    Text("Add")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppTheme.pillPurple)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.quickAddBackground.opacity(0.85))
        )
    }

    private func commitTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreateTask(trimmed)
        newTaskTitle = ""
        isAddingTask = false
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

private struct DayBadge: View {
    let date: Date
    let relativeLabel: String
    let isToday: Bool
    let width: CGFloat

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            VStack(alignment: .center, spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isToday ? .white : AppTheme.textPrimary)

                Text(relativeLabel.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(isToday ? .white.opacity(0.85) : AppTheme.textSecondary)

                Text(weekdayString.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isToday ? .white.opacity(0.7) : AppTheme.metadataText)
            }
            .frame(maxWidth: .infinity)

            Circle()
                .fill(isToday ? AppTheme.accent : AppTheme.cardBorder.opacity(0.9))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(AppTheme.contentBackground, lineWidth: 2)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: badgeColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isToday ? AppTheme.selectionBorder : AppTheme.cardBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var badgeColors: [Color] {
        if isToday {
            return [AppTheme.accent, AppTheme.pillPurple]
        }
        return [
            AppTheme.cardBackground.opacity(0.9),
            AppTheme.cardBackground.opacity(0.7)
        ]
    }
}

private struct MonthChipButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppTheme.cardBackground.opacity(0.7))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppTheme.cardBorder.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundColor(AppTheme.textSecondary)
    }
}

private struct SectionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(AppTheme.textSecondary)
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.timeRangeString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.metadataText)
                Text(event.durationDescription)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.metadataText.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                HStack(spacing: 8) {
                    Capsule()
                        .fill(color(for: event.calendarType).opacity(0.15))
                        .frame(width: 6, height: 6)

                    Text(event.calendarType.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(color(for: event.calendarType))

                    if let location = event.location {
                        Text("•")
                            .foregroundColor(AppTheme.metadataText)
                        Text(location)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppTheme.metadataText)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func color(for type: CalendarEvent.CalendarType) -> Color {
        switch type {
        case .work: return AppTheme.accent
        case .personal: return Color.pink
        case .focus: return AppTheme.pillPurple
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environmentObject(AppState())
        .frame(width: 900, height: 800)
}
