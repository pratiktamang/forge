import SwiftUI

struct HabitCalendarView: View {
    let habit: Habit?
    let completionDates: Set<Date>
    let onToggle: (Date) -> Void

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearString)
                    .font(.headline)

                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }

            // Day headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { item in
                    if let date = item {
                        DayCell(
                            date: date,
                            isDue: habit?.isDueOn(date) ?? false,
                            isCompleted: isCompleted(date),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date()
                        )
                        .onTapGesture {
                            if date <= Date() && (habit?.isDueOn(date) ?? false) {
                                onToggle(date)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var weekdaySymbols: [String] {
        calendar.veryShortWeekdaySymbols
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []

        // Get the first day of the grid (might be from previous month)
        var currentDate = monthFirstWeek.start

        // Fill in 6 weeks (42 days) to ensure consistent grid size
        for _ in 0..<42 {
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if days.isEmpty || days.last != nil {
                // Before month starts or right after it ends
                days.append(nil)
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Trim trailing nils
        while days.last == nil && !days.isEmpty {
            days.removeLast()
        }

        return days
    }

    // MARK: - Helpers

    private func isCompleted(_ date: Date) -> Bool {
        let normalizedDate = calendar.startOfDay(for: date)
        return completionDates.contains(normalizedDate)
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isDue: Bool
    let isCompleted: Bool
    let isToday: Bool
    let isFuture: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            // Today indicator
            if isToday {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            }

            // Completion state
            if isCompleted {
                Circle()
                    .fill(Color.green)
                Text(dayNumber)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
            } else if isDue && !isFuture {
                // Missed due day
                Circle()
                    .fill(Color.red.opacity(0.15))
                Text(dayNumber)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if isDue {
                // Future due day
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                Text(dayNumber)
                    .font(.caption)
                    .foregroundColor(.primary)
            } else {
                // Not a due day
                Text(dayNumber)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .frame(width: 32, height: 32)
        .contentShape(Circle())
    }

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }
}

// MARK: - Preview

#Preview {
    let today = Date()
    let calendar = Calendar.current
    let completions: Set<Date> = [
        calendar.date(byAdding: .day, value: -1, to: today)!,
        calendar.date(byAdding: .day, value: -2, to: today)!,
        calendar.date(byAdding: .day, value: -3, to: today)!,
        calendar.date(byAdding: .day, value: -5, to: today)!,
    ].map { calendar.startOfDay(for: $0) }.reduce(into: Set<Date>()) { $0.insert($1) }

    return HabitCalendarView(
        habit: Habit(title: "Test Habit"),
        completionDates: completions,
        onToggle: { _ in }
    )
    .padding()
    .frame(width: 350)
}
