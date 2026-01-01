import SwiftUI

struct GoalTimelineView: View {
    let year: Int
    @State private var initiatives: [InitiativeRepository.TimelineItem] = []
    @State private var isLoading = true

    private let repository = InitiativeRepository()
    private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Timeline")
                    .font(.headline)

                Spacer()

                Text(String(year))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else if initiatives.isEmpty {
                emptyState
            } else {
                timelineContent
            }
        }
        .task {
            await loadTimeline()
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(spacing: 0) {
            // Month headers
            monthHeaders

            // Timeline rows
            ForEach(initiatives, id: \.initiative.id) { item in
                timelineRow(item)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var monthHeaders: some View {
        HStack(spacing: 0) {
            // Label column
            Text("Initiative")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
                .padding(.horizontal, 8)

            // Month columns
            ForEach(0..<12, id: \.self) { index in
                Text(months[index])
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
    }

    @ViewBuilder
    private func timelineRow(_ item: InitiativeRepository.TimelineItem) -> some View {
        HStack(spacing: 0) {
            // Initiative name
            VStack(alignment: .leading, spacing: 2) {
                Text(item.initiative.title)
                    .font(.caption)
                    .lineLimit(1)

                if let goal = item.goal {
                    Text(goal.title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 8)

            // Timeline bar
            GeometryReader { geometry in
                let monthWidth = geometry.size.width / 12

                if let startMonth = monthIndex(item.startDate),
                   let endMonth = monthIndex(item.endDate) {
                    let startX = CGFloat(startMonth) * monthWidth
                    let width = CGFloat(endMonth - startMonth + 1) * monthWidth

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor(item.initiative.status))
                        .frame(width: max(width, monthWidth), height: 20)
                        .offset(x: startX)
                }
            }
            .frame(height: 30)
        }
        .padding(.vertical, 4)

        Divider()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundColor(.secondary)

            Text("No initiatives with dates")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Add start and target dates to initiatives to see them on the timeline")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func loadTimeline() async {
        do {
            initiatives = try await repository.fetchTimelineItems(year: year)
        } catch {
            print("Failed to load timeline: \(error)")
        }
        isLoading = false
    }

    private func monthIndex(_ date: Date?) -> Int? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let dateYear = calendar.component(.year, from: date)

        // If date is before this year, return 0 (January)
        if dateYear < year { return 0 }
        // If date is after this year, return 11 (December)
        if dateYear > year { return 11 }

        return calendar.component(.month, from: date) - 1
    }

    private func statusColor(_ status: InitiativeStatus) -> Color {
        switch status {
        case .active: return .blue.opacity(0.7)
        case .onHold: return .orange.opacity(0.7)
        case .completed: return .green.opacity(0.7)
        case .archived: return .secondary.opacity(0.7)
        }
    }
}

// MARK: - Quarterly Progress View

struct QuarterlyProgressView: View {
    let year: Int
    let goals: [Goal]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quarterly Progress")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { quarter in
                    quarterCard(quarter)
                }
            }
        }
    }

    @ViewBuilder
    private func quarterCard(_ quarter: Int) -> some View {
        let quarterGoals = goals.filter { $0.quarter == quarter }
        let avgProgress = quarterGoals.isEmpty ? 0 : quarterGoals.reduce(0) { $0 + $1.progress } / Double(quarterGoals.count)

        VStack(spacing: 8) {
            Text("Q\(quarter)")
                .font(.headline)

            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: avgProgress)
                    .stroke(progressColor(avgProgress), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(avgProgress * 100))%")
                    .font(.caption.weight(.bold))
            }
            .frame(width: 60, height: 60)

            Text("\(quarterGoals.count) goals")
                .font(.caption)
                .foregroundColor(.secondary)

            if isCurrentQuarter(quarter) {
                Text("Current")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .blue }
        if progress >= 0.25 { return .orange }
        return .secondary
    }

    private func isCurrentQuarter(_ quarter: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        let currentQuarter = ((month - 1) / 3) + 1
        return year == currentYear && quarter == currentQuarter
    }
}

// MARK: - Preview

#Preview {
    VStack {
        GoalTimelineView(year: 2025)
        QuarterlyProgressView(year: 2025, goals: [])
    }
    .padding()
}
