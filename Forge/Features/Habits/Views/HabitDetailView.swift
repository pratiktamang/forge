import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct HabitDetailView: View {
    @StateObject private var viewModel: HabitDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    init(habitId: String) {
        _viewModel = StateObject(wrappedValue: HabitDetailViewModel(habitId: habitId))
    }

    var body: some View {
        Group {
            if let habit = viewModel.habit {
                habitDetailContent(habit)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Habit not found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func habitDetailContent(_ habit: Habit) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection(habit)

                Divider()

                // Statistics
                statisticsSection

                Divider()

                // Properties
                propertiesSection(habit)

                Divider()

                // Calendar
                calendarSection

                Divider()

                // Recent Completions
                recentCompletionsSection

                Spacer()
            }
            .padding(24)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(_ habit: Habit) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            if let icon = habit.icon {
                ZStack {
                    Circle()
                        .fill(habitColor(habit).opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(habitColor(habit))
                }
            }

            // Title and metadata
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.title)
                    .font(.title2.weight(.semibold))

                if let description = habit.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    // Frequency badge
                    Label(frequencyText(habit), systemImage: "repeat")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    Text("Created \(habit.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Today's completion button
            VStack(spacing: 4) {
                let isCompletedToday = viewModel.completionDates.contains(
                    Calendar.current.startOfDay(for: Date())
                )

                Button(action: {
                    AsyncTask { await viewModel.toggleCompletion(on: Date()) }
                }) {
                    ZStack {
                        Circle()
                            .stroke(habitColor(habit), lineWidth: 3)
                            .frame(width: 48, height: 48)

                        if isCompletedToday {
                            Circle()
                                .fill(habitColor(habit))
                                .frame(width: 48, height: 48)
                            Image(systemName: "checkmark")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(isCompletedToday ? "Done" : "Today")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statCard(
                    title: "Current Streak",
                    value: "\(viewModel.streakInfo?.currentStreak ?? 0)",
                    icon: "flame.fill",
                    color: .orange
                )

                statCard(
                    title: "Longest Streak",
                    value: "\(viewModel.streakInfo?.longestStreak ?? 0)",
                    icon: "trophy.fill",
                    color: .yellow
                )

                statCard(
                    title: "Total",
                    value: "\(viewModel.streakInfo?.totalCompletions ?? 0)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                statCard(
                    title: "30-Day Rate",
                    value: "\(Int((viewModel.streakInfo?.completionRate ?? 0) * 100))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            }
        }
    }

    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title.monospacedDigit().bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Properties Section

    @ViewBuilder
    private func propertiesSection(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 12) {
                propertyRow(icon: "repeat", label: "Frequency", value: frequencyText(habit))

                if habit.frequencyType != .daily, let days = habit.frequencyDays {
                    propertyRow(icon: "calendar", label: "Days", value: formatDays(days))
                }

                if let reminderTime = habit.reminderTime {
                    propertyRow(icon: "bell", label: "Reminder", value: reminderTime)
                }

                if let lastCompleted = viewModel.streakInfo?.lastCompletedDate {
                    propertyRow(
                        icon: "checkmark.seal",
                        label: "Last Completed",
                        value: lastCompleted.formatted(.relative(presentation: .named))
                    )
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func propertyRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Calendar Section

    @ViewBuilder
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Completion History")
                .font(.headline)

            HabitCalendarView(
                habit: viewModel.habit,
                completionDates: viewModel.completionDates,
                onToggle: { date in
                    AsyncTask { await viewModel.toggleCompletion(on: date) }
                }
            )
        }
    }

    // MARK: - Recent Completions Section

    @ViewBuilder
    private var recentCompletionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)

            if viewModel.completions.isEmpty {
                Text("No completions yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.completions.prefix(10)) { completion in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Text(completion.completedDate.formatted(date: .abbreviated, time: .omitted))

                            Spacer()

                            Text(completion.completedDate.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)

                        if completion.id != viewModel.completions.prefix(10).last?.id {
                            Divider()
                        }
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func habitColor(_ habit: Habit) -> Color {
        if let hex = habit.color {
            return Color(hex: hex)
        }
        return .accentColor
    }

    private func frequencyText(_ habit: Habit) -> String {
        switch habit.frequencyType {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .custom:
            return "Custom"
        }
    }

    private func formatDays(_ days: [Int]) -> String {
        let dayNames = days.sorted().compactMap { weekdayName(for: $0) }
        return dayNames.joined(separator: ", ")
    }

    private func weekdayName(for weekday: Int) -> String? {
        let calendar = Calendar.current
        guard let date = calendar.date(from: DateComponents(weekday: weekday)) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    HabitDetailView(habitId: "preview")
        .frame(width: 500, height: 800)
}
