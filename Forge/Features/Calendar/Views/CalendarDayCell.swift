import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let tasks: [Task]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            // Day number
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 32, height: 32)
                }

                Text(dayNumber)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)
            }
            .frame(height: 32)

            // Task indicators
            if !tasks.isEmpty {
                taskIndicators
            } else {
                Spacer()
                    .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isCurrentMonth ? 1 : 0.3)
    }

    // MARK: - Computed Properties

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isCurrentMonth {
            return .secondary
        } else {
            return .primary
        }
    }

    // MARK: - Task Indicators

    @ViewBuilder
    private var taskIndicators: some View {
        let visibleTasks = Array(tasks.prefix(3))
        let remainingCount = tasks.count - 3

        HStack(spacing: 3) {
            ForEach(visibleTasks, id: \.id) { task in
                Circle()
                    .fill(indicatorColor(for: task))
                    .frame(width: 6, height: 6)
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 8)
    }

    private func indicatorColor(for task: Task) -> Color {
        if task.status == .completed {
            return .green
        }

        switch task.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        case .none:
            return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        CalendarDayCell(
            date: Date(),
            tasks: [],
            isSelected: false,
            isToday: true,
            isCurrentMonth: true
        )

        CalendarDayCell(
            date: Date(),
            tasks: [
                Task(title: "High priority", priority: .high),
                Task(title: "Medium", priority: .medium)
            ],
            isSelected: true,
            isToday: false,
            isCurrentMonth: true
        )

        CalendarDayCell(
            date: Date(),
            tasks: [
                Task(title: "Task 1"),
                Task(title: "Task 2"),
                Task(title: "Task 3"),
                Task(title: "Task 4"),
                Task(title: "Task 5")
            ],
            isSelected: false,
            isToday: false,
            isCurrentMonth: true
        )

        CalendarDayCell(
            date: Date(),
            tasks: [],
            isSelected: false,
            isToday: false,
            isCurrentMonth: false
        )
    }
    .padding()
}
