import SwiftUI

struct HabitRowView: View {
    let habit: Habit
    let isCompletedToday: Bool
    let currentStreak: Int
    let onToggleComplete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            // Completion circle
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .stroke(habitColor, lineWidth: 2.5)
                        .frame(width: 28, height: 28)

                    if isCompletedToday {
                        Circle()
                            .fill(habitColor)
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            // Icon
            if let icon = habit.icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(habitColor)
                    .frame(width: 20)
            }

            // Title and frequency
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.body)
                    .foregroundColor(isCompletedToday ? .secondary : .primary)

                Text(frequencyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Streak badge
            if currentStreak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(streakColor)
                    Text("\(currentStreak)")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(streakColor.opacity(0.15))
                .cornerRadius(12)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Computed Properties

    private var habitColor: Color {
        if let colorHex = habit.color {
            return Color(hex: colorHex)
        }
        return .accentColor
    }

    private var streakColor: Color {
        if currentStreak >= 30 {
            return .orange
        } else if currentStreak >= 7 {
            return .yellow
        }
        return .secondary
    }

    private var frequencyDescription: String {
        switch habit.frequencyType {
        case .daily:
            return "Every day"
        case .weekly:
            return formatWeeklyDays()
        case .custom:
            return formatCustomDays()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onToggleComplete) {
            Label(
                isCompletedToday ? "Mark Incomplete" : "Mark Complete",
                systemImage: isCompletedToday ? "circle" : "checkmark.circle"
            )
        }

        Divider()

        Button(role: .destructive) {
            // Handled by parent
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func formatWeeklyDays() -> String {
        guard let days = habit.frequencyDays, !days.isEmpty else {
            return "Weekly"
        }

        let dayNames = days.sorted().compactMap { weekdayName(for: $0) }
        if dayNames.count <= 3 {
            return dayNames.joined(separator: ", ")
        } else {
            return "\(dayNames.count) days/week"
        }
    }

    private func formatCustomDays() -> String {
        guard let days = habit.frequencyDays, !days.isEmpty else {
            return "Custom"
        }

        let dayNames = days.sorted().compactMap { weekdayName(for: $0) }
        if dayNames.count <= 3 {
            return dayNames.joined(separator: ", ")
        } else {
            return "\(dayNames.count) days/week"
        }
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
    VStack(spacing: 0) {
        HabitRowView(
            habit: Habit(title: "Morning meditation", color: "7C3AED", icon: "brain.head.profile"),
            isCompletedToday: false,
            currentStreak: 15,
            onToggleComplete: {}
        )
        Divider()
        HabitRowView(
            habit: Habit(title: "Exercise", frequencyType: .weekly, frequencyDays: [2, 4, 6], color: "10B981", icon: "figure.run"),
            isCompletedToday: true,
            currentStreak: 3,
            onToggleComplete: {}
        )
        Divider()
        HabitRowView(
            habit: Habit(title: "Read 30 minutes", color: "3B82F6", icon: "book.fill"),
            isCompletedToday: false,
            currentStreak: 42,
            onToggleComplete: {}
        )
    }
    .padding()
    .frame(width: 400)
}
