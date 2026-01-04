import SwiftUI

struct CalendarDayCell: View {
    let date: Date
    let tasks: [Task]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 17, weight: isToday ? .semibold : .medium, design: .rounded))
                    .foregroundColor(textColor)

                Text(weekdaySymbol.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? textColor.opacity(0.9) : AppTheme.metadataText.opacity(isCurrentMonth ? 0.8 : 0.4))
            }

            if tasks.isEmpty {
                Capsule()
                    .fill(AppTheme.cardBorder.opacity(0.4))
                    .frame(maxWidth: 40, maxHeight: 4)
                    .overlay(
                        Text("free")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.metadataText.opacity(0.9))
                            .offset(y: -10)
                    )
            } else {
                workloadBar
                badgeRow
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(backgroundShape)
        .overlay(overlayStroke)
        .shadow(color: isSelected ? AppTheme.accent.opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
        .scaleEffect(isSelected ? 1.03 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isCurrentMonth ? 1 : 0.35)
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: isSelected)
    }

    // MARK: - Computed Properties

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    private var weekdaySymbol: String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.shortWeekdaySymbols
        guard index >= 0 && index < symbols.count else { return "" }
        return String(symbols[index].prefix(2))
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

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var backgroundColors: [Color] {
        if isSelected {
            return [
                AppTheme.selectionBackground.opacity(0.9),
                AppTheme.selectionBackground.opacity(0.7)
            ]
        } else if isToday {
            return [
                AppTheme.cardBackground.opacity(0.9),
                AppTheme.cardBackground.opacity(0.65)
            ]
        } else {
            return [
                AppTheme.cardBackground.opacity(0.55),
                AppTheme.cardBackground.opacity(0.4)
            ]
        }
    }

    private var overlayStroke: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                isToday
                    ? AppTheme.accent.opacity(isSelected ? 0.9 : 0.6)
                    : AppTheme.cardBorder.opacity(isSelected ? 0.9 : 0.3),
                lineWidth: isToday ? 1.6 : 1
            )
    }

    private var workloadBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let segments = workloadSegments

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.cardBorder.opacity(0.4))
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    Capsule()
                        .fill(segment.color)
                        .frame(width: width * segment.ratio)
                        .offset(x: width * cumulativeRatio(upTo: index, in: segments))
                }
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.25), value: tasks.count)
    }

    private var badgeRow: some View {
        HStack(spacing: 6) {
            let counts = workloadCounts
            if counts.overdue > 0 {
                TaskIndicatorBadge(icon: "exclamationmark.triangle.fill", text: "\(counts.overdue)", color: .red)
            }
            if counts.flagged > 0 {
                TaskIndicatorBadge(icon: "flag.fill", text: "\(counts.flagged)", color: .orange)
            }
            if counts.completed > 0 {
                TaskIndicatorBadge(icon: "checkmark.circle.fill", text: "\(counts.completed)", color: AppTheme.accent)
            }
            if counts.remaining > 0 {
                TaskIndicatorBadge(icon: "circlebadge", text: "\(counts.remaining)", color: AppTheme.metadataText)
            }
        }
        .frame(height: 12)
    }

    private var workloadCounts: (overdue: Int, flagged: Int, completed: Int, remaining: Int) {
        tasks.reduce(into: (overdue: 0, flagged: 0, completed: 0, remaining: 0)) { result, task in
            if task.status == .completed {
                result.completed += 1
            } else if task.isOverdue {
                result.overdue += 1
            } else if task.isFlagged {
                result.flagged += 1
            } else {
                result.remaining += 1
            }
        }
    }

    private var workloadSegments: [(ratio: CGFloat, color: Color)] {
        guard !tasks.isEmpty else { return [] }
        let total = CGFloat(tasks.count)

        let counts = workloadCounts
        let segments: [(Int, Color)] = [
            (counts.overdue, .red),
            (counts.flagged, .orange),
            (counts.completed, AppTheme.accent),
            (counts.remaining, AppTheme.metadataText.opacity(0.6))
        ]

        return segments.compactMap { count, color in
            guard count > 0 else { return nil }
            return (CGFloat(count) / total, color)
        }
    }

    private func cumulativeRatio(upTo index: Int, in segments: [(ratio: CGFloat, color: Color)]) -> CGFloat {
        guard index > 0 else { return 0 }
        return segments[..<index].reduce(CGFloat(0)) { $0 + $1.ratio }
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
                Task(title: "Flagged task", isFlagged: true),
                Task(title: "Normal task")
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

private struct TaskIndicatorBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
    }
}
