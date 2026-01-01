import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject var appState: AppState

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            // Month header with navigation
            monthHeader
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            // Calendar grid
            calendarGrid
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Selected date task list
            CalendarTaskList(viewModel: viewModel)
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Today") {
                    viewModel.goToToday()
                }
                .disabled(viewModel.isCurrentMonth && calendar.isDateInToday(viewModel.selectedDate))
            }
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.monthYearString)
                .font(.headline)

            Spacer()

            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(daysInMonth, id: \.self) { item in
                    if let date = item {
                        let normalizedDate = calendar.startOfDay(for: date)
                        CalendarDayCell(
                            date: date,
                            tasks: viewModel.tasksByDate[normalizedDate] ?? [],
                            isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: viewModel.displayedMonth, toGranularity: .month)
                        )
                        .onTapGesture {
                            viewModel.selectDate(date)
                        }
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }
        }
    }

    // MARK: - Days Calculation

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }

        var days: [Date?] = []
        var currentDate = monthFirstWeek.start

        // Fill in 6 weeks (42 days) for consistent grid
        for _ in 0..<42 {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environmentObject(AppState())
        .frame(width: 350, height: 600)
}
