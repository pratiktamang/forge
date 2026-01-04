import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct CalendarDetailView: View {
    @StateObject private var viewModel: CalendarDayDetailViewModel
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle = ""
    @FocusState private var isAddingTask: Bool

    init(date: Date) {
        _viewModel = StateObject(wrappedValue: CalendarDayDetailViewModel(date: date))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                eventsSection
                Divider().overlay(AppTheme.cardBorder.opacity(0.6))
                tasksSection
            }
            .padding(24)
        }
        .background(AppTheme.contentBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateString)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text("\(viewModel.tasks.count) tasks • \(viewModel.events.count) events")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Events")

            if viewModel.events.isEmpty {
                Text("No meetings scheduled.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.metadataText)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.events) { event in
                        CalendarDetailEventRow(event: event)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppTheme.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Tasks")

            if viewModel.tasks.isEmpty {
                Text("Nothing on deck. Add a task when you're ready.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.metadataText)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.tasks) { task in
                        TaskRowView(
                            task: task,
                            isSelected: appState.selectedTaskId == task.id,
                            style: .minimal,
                            onToggleComplete: {
                                AsyncTask { await viewModel.toggleComplete(task) }
                            },
                            onToggleFlag: {
                                AsyncTask { await viewModel.toggleFlag(task) }
                            },
                            onDelete: {
                                AsyncTask { await viewModel.deleteTask(task) }
                            }
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                appState.selectedTaskId = task.id
                            }
                        }
                    }
                }
            }

            quickAddBar
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(AppTheme.accent)
                .font(.system(size: 20, weight: .semibold))

            TextField("Add task for this day...", text: $newTaskTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)
                .focused($isAddingTask)
                .onSubmit(addTask)

            if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: addTask) {
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
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
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        AsyncTask {
            await viewModel.createTask(title: trimmed)
            newTaskTitle = ""
            isAddingTask = false
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: viewModel.date)
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.metadataText)
    }
}

private struct CalendarDetailEventRow: View {
    let event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.timeRangeString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.metadataText)
                Spacer()
                Text(event.durationDescription)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.metadataText.opacity(0.8))
            }

            Text(event.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 8) {
                Circle()
                    .fill(color(for: event.calendarType))
                    .frame(width: 7, height: 7)
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
    }

    private func color(for type: CalendarEvent.CalendarType) -> Color {
        switch type {
        case .work: return AppTheme.accent
        case .personal: return Color.pink
        case .focus: return AppTheme.pillPurple
        }
    }
}
