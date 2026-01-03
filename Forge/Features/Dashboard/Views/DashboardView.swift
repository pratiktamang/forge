import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct DashboardView: View {
    @StateObject private var goalViewModel = GoalViewModel()
    @State private var selectedYear: Int
    @State private var hoveredMilestone: DashboardHighlight?

    private let calendar = Calendar.current

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                HStack(alignment: .top, spacing: 20) {
                    quarterColumn
                        .frame(width: 280)

                    yearCalendar
                        .frame(maxWidth: .infinity)

                    legendColumn
                        .frame(width: 220)
                }
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .background(AppTheme.contentBackground)
        .onAppear {
            goalViewModel.startObserving()
        }
        .onDisappear {
            goalViewModel.stopObserving()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Big Picture")
                    .font(.largeTitle.weight(.bold))
                Text("Your year at a glance.")
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("Year", selection: $selectedYear) {
                ForEach(goalViewModel.availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .labelsHidden()
            .frame(width: 120)
            .pickerStyle(.menu)
        }
    }

    // MARK: - Quarter Checklist Column

    private var quarterColumn: some View {
        VStack(spacing: 16) {
            ForEach(1...4, id: \.self) { quarter in
                quarterChecklist(quarter: quarter, goals: quarterGoals(for: quarter))
            }
        }
    }

    @ViewBuilder
    private func quarterChecklist(quarter: Int, goals: [Goal]) -> some View {
        VStack(spacing: 0) {
            Text("Q\(quarter)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black)

            VStack(alignment: .leading, spacing: 0) {
                if goals.isEmpty {
                    ForEach(0..<5, id: \.self) { _ in
                        dottedPlaceholder
                    }
                } else {
                    ForEach(goals) { goal in
                        quarterRow(goal: goal)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(AppTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func quarterRow(goal: Goal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: { toggleGoal(goal) }) {
                Image(systemName: goal.status == .completed ? "checkmark.square.fill" : "square")
                    .foregroundColor(goal.status == .completed ? AppTheme.accent : AppTheme.textSecondary)
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)

                if let description = goal.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
        }
    }

    private var dottedPlaceholder: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 32)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(AppTheme.cardBorder)
                    .padding(.horizontal, 12)
            )
            .padding(.vertical, 4)
    }

    private func quarterGoals(for quarter: Int) -> [Goal] {
        goalViewModel.goals(for: selectedYear)?.quarterlyGoals[quarter] ?? []
    }

    private func toggleGoal(_ goal: Goal) {
        AsyncTask {
            if goal.status == .completed {
                var updated = goal
                updated.status = .active
                updated.progress = min(updated.progress, 0.99)
                await goalViewModel.updateGoal(updated)
            } else {
                await goalViewModel.completeGoal(goal)
            }
        }
    }

    // MARK: - Year Calendar

    private var yearCalendar: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
            ForEach(1...12, id: \.self) { month in
                monthCard(for: month)
            }
        }
    }

    private func monthCard(for month: Int) -> some View {
        VStack(spacing: 0) {
            Text(monthTitle(month))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.black)

            VStack(spacing: 4) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(daysInMonth(month), id: \.self) { date in
                        if let date = date {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(height: 22)
                        }
                    }
                }
            }
            .padding(8)
            .background(AppTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func dayCell(for date: Date) -> some View {
        let highlight = highlightForDate(date)
        let isToday = calendar.isDateInToday(date)
        let usesOutline = highlight?.style == .outline
        let fillColor = highlight.map { $0.color.opacity(usesOutline ? 0.2 : 0.85) } ?? Color.clear
        let borderColor: Color
        if usesOutline {
            borderColor = highlight?.color ?? .clear
        } else {
            borderColor = isToday ? AppTheme.accent : .clear
        }

        let textColor: Color
        if let highlight = highlight {
            textColor = highlight.style == .outline ? highlight.color : .white
        } else if isToday {
            textColor = AppTheme.accent
        } else {
            textColor = AppTheme.textPrimary
        }

        // Check if we should dim this date (when hovering a milestone in the key)
        let isInHoveredMilestone = hoveredMilestone?.dateRange.contains(date) ?? false
        let shouldDim = hoveredMilestone != nil && !isInHoveredMilestone

        return Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 20)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: usesOutline || isToday ? 1.5 : 0)
            )
            .foregroundColor(textColor)
            .opacity(shouldDim ? 0.2 : 1.0)
            .scaleEffect(isInHoveredMilestone && hoveredMilestone != nil ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: hoveredMilestone?.id)
    }

    private func daysInMonth(_ month: Int) -> [Date?] {
        guard let monthStart = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)),
              let daysRange = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let weekOffset = ((firstWeekday - calendar.firstWeekday) + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: weekOffset)

        for day in daysRange {
            if let date = calendar.date(from: DateComponents(year: selectedYear, month: month, day: day)) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        while days.count < 42 {
            days.append(nil)
        }

        return days
    }

    private func monthTitle(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let date = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)) ?? Date()
        return formatter.string(from: date)
    }

    private func highlightForDate(_ date: Date) -> DashboardHighlight? {
        milestoneHighlights.first { $0.dateRange.contains(date) }
    }

    private var milestoneHighlights: [DashboardHighlight] {
        DashboardHighlight.sampleMilestones(for: selectedYear)
    }

    // MARK: - Legend

    private var legendColumn: some View {
        VStack(spacing: 0) {
            Text("Key")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.black)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(milestoneHighlights) { milestone in
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(milestone.color)
                                .frame(width: 20, height: 20)
                                .cornerRadius(4)
                            Text(milestone.title)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(hoveredMilestone?.id == milestone.id ? milestone.color.opacity(0.15) : Color.clear)
                        .onHover { isHovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                hoveredMilestone = isHovering ? milestone : nil
                            }
                        }

                        Divider()
                    }
                }
            }
            .background(AppTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Supporting Models

private enum MilestoneCategory: String, CaseIterable, Identifiable {
    case launch = "launch"
    case marketing = "marketing"
    case travel = "travel"
    case planning = "planning"
    case review = "review"
    case learning = "learning"
    case buffer = "buffer"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launch: return "Launch Week"
        case .marketing: return "Marketing Push"
        case .travel: return "Travel / Vacation"
        case .planning: return "Planning & Strategy"
        case .review: return "Review & Retro"
        case .learning: return "Learning / Conference"
        case .buffer: return "Buffer / Flex"
        }
    }

    var color: Color {
        switch self {
        case .launch: return Color(hex: "EF4444")     // Red
        case .marketing: return Color(hex: "F59E0B")  // Amber
        case .travel: return Color(hex: "10B981")     // Green
        case .planning: return Color(hex: "8B5CF6")   // Purple
        case .review: return Color(hex: "6366F1")     // Indigo
        case .learning: return Color(hex: "EC4899")   // Pink
        case .buffer: return Color(hex: "6B7280")     // Gray
        }
    }
}

private struct DashboardHighlight: Identifiable, Equatable {
    enum Style: Equatable {
        case solid
        case outline
    }

    var id: String { title }
    let title: String
    let color: Color
    let dateRange: ClosedRange<Date>
    let style: Style
    let category: MilestoneCategory?

    init(title: String, color: Color, dateRange: ClosedRange<Date>, style: Style = .solid, category: MilestoneCategory? = nil) {
        self.title = title
        self.color = color
        self.dateRange = dateRange
        self.style = style
        self.category = category
    }

    static func == (lhs: DashboardHighlight, rhs: DashboardHighlight) -> Bool {
        lhs.title == rhs.title
    }

    static func sampleMilestones(for year: Int) -> [DashboardHighlight] {
        let cal = Calendar.current
        func d(_ month: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }

        return [
            // Q1
            DashboardHighlight(title: "MVP Launch", color: Color(hex: "EF4444"),
                               dateRange: d(1, 20)...d(1, 24), category: .launch),
            DashboardHighlight(title: "Beta Testing Sprint", color: Color(hex: "F59E0B"),
                               dateRange: d(2, 10)...d(2, 17), category: .launch),
            DashboardHighlight(title: "API v1 Release", color: Color(hex: "3B82F6"),
                               dateRange: d(3, 10)...d(3, 14), category: .launch),

            // Q2
            DashboardHighlight(title: "iOS App Launch", color: Color(hex: "10B981"),
                               dateRange: d(4, 21)...d(4, 25), category: .launch),
            DashboardHighlight(title: "Product Hunt Launch", color: Color(hex: "FF6154"),
                               dateRange: d(5, 12)...d(5, 16), category: .marketing),
            DashboardHighlight(title: "Lisbon Trip with Family", color: Color(hex: "06B6D4"),
                               dateRange: d(6, 14)...d(6, 22), category: .travel),

            // Q3
            DashboardHighlight(title: "Sync Engine Ship", color: Color(hex: "0EA5E9"),
                               dateRange: d(7, 21)...d(7, 25), category: .launch),
            DashboardHighlight(title: "SwiftConf, Cologne", color: Color(hex: "EC4899"),
                               dateRange: d(9, 8)...d(9, 12), category: .learning),

            // Q4
            DashboardHighlight(title: "Mac App Launch", color: Color(hex: "14B8A6"),
                               dateRange: d(10, 20)...d(10, 24), category: .launch),
            DashboardHighlight(title: "Swiss Alps Ski Trip", color: Color(hex: "2DD4BF"),
                               dateRange: d(12, 21)...d(12, 31), category: .travel),
        ]
    }
}


// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .frame(width: 1200, height: 700)
}
