import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct GoalListView: View {
    @StateObject private var viewModel = GoalViewModel()
    @EnvironmentObject var appState: AppState
    @State private var isAddingGoal = false
    @State private var selectedYearTab: Int

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYearTab = State(initialValue: currentYear)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Year tabs
            yearTabs

            Divider()

            // Content
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let yearData = viewModel.goals(for: selectedYearTab) {
                goalContent(yearData)
            } else {
                emptyYearState
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isAddingGoal = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingGoal) {
            AddGoalSheet(year: selectedYearTab, viewModel: viewModel)
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Year Tabs

    private var yearTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableYears, id: \.self) { year in
                    Button(action: { selectedYearTab = year }) {
                        Text(String(year))
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedYearTab == year ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundColor(selectedYearTab == year ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Add year button
                Button(action: addNextYear) {
                    Image(systemName: "plus")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Goal Content

    @ViewBuilder
    private func goalContent(_ yearData: GoalRepository.GoalsByYear) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Yearly Goals
                if !yearData.yearlyGoals.isEmpty {
                    yearlyGoalsSection(yearData.yearlyGoals)
                }

                // Quarterly Goals
                quartersSection(yearData.quarterlyGoals)
            }
            .padding(16)
        }
    }

    // MARK: - Yearly Goals Section

    @ViewBuilder
    private func yearlyGoalsSection(_ goals: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Yearly Goals")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(action: { isAddingGoal = true }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(goals) { goal in
                GoalCard(goal: goal, style: .yearly)
                    .onTapGesture {
                        appState.selectedGoalId = goal.id
                    }
            }
        }
    }

    // MARK: - Quarters Section

    @ViewBuilder
    private func quartersSection(_ quarterlyGoals: [Int: [Goal]]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quarters")
                .font(.title2.weight(.semibold))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(1...4, id: \.self) { quarter in
                    quarterCard(quarter: quarter, goals: quarterlyGoals[quarter] ?? [])
                }
            }
        }
    }

    @ViewBuilder
    private func quarterCard(quarter: Int, goals: [Goal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Q\(quarter)")
                    .font(.headline)

                Spacer()

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

            if goals.isEmpty {
                Text("No goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ForEach(goals) { goal in
                    GoalCard(goal: goal, style: .quarterly)
                        .onTapGesture {
                            appState.selectedGoalId = goal.id
                        }
                }
            }

            Button(action: { addQuarterlyGoal(quarter: quarter) }) {
                Label("Add Goal", systemImage: "plus")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyYearState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No goals for \(selectedYearTab)")
                .font(.headline)
                .foregroundColor(.secondary)

            Button(action: { isAddingGoal = true }) {
                Label("Add Your First Goal", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func isCurrentQuarter(_ quarter: Int) -> Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return selectedYearTab == currentYear && quarter == viewModel.currentQuarter
    }

    private func addNextYear() {
        let maxYear = viewModel.availableYears.max() ?? Calendar.current.component(.year, from: Date())
        selectedYearTab = maxYear + 1
    }

    private func addQuarterlyGoal(quarter: Int) {
        // TODO: Show add quarterly goal sheet
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    let style: Style

    enum Style {
        case yearly
        case quarterly
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(style == .yearly ? .headline : .subheadline)
                    .lineLimit(2)

                Spacer()

                statusBadge
            }

            if let description = goal.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Progress bar
            ProgressView(value: goal.progress)
                .tint(progressColor)

            HStack {
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if let targetDate = goal.targetDate {
                    Text(targetDate.formatted(.dateTime.month().day()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        Group {
            switch goal.status {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .archived:
                Image(systemName: "archivebox")
                    .foregroundColor(.secondary)
            case .active:
                EmptyView()
            }
        }
    }

    private var progressColor: Color {
        if goal.progress >= 1.0 {
            return .green
        } else if goal.progress >= 0.5 {
            return .blue
        } else if goal.progress >= 0.25 {
            return .orange
        } else {
            return .secondary
        }
    }

    private var borderColor: Color {
        if goal.status == .completed {
            return .green.opacity(0.3)
        }
        return Color.secondary.opacity(0.1)
    }
}

// MARK: - Add Goal Sheet

struct AddGoalSheet: View {
    let year: Int
    @ObservedObject var viewModel: GoalViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var goalType: GoalType = .yearly
    @State private var quarter: Int = 1

    var body: some View {
        VStack(spacing: 20) {
            Text("New Goal")
                .font(.headline)

            Form {
                TextField("Goal title", text: $title)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(3...5)

                Picker("Type", selection: $goalType) {
                    Text("Yearly").tag(GoalType.yearly)
                    Text("Quarterly").tag(GoalType.quarterly)
                }

                if goalType == .quarterly {
                    Picker("Quarter", selection: $quarter) {
                        ForEach(1...4, id: \.self) { q in
                            Text("Q\(q)").tag(q)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Create") {
                    AsyncTask {
                        if goalType == .yearly {
                            await viewModel.createYearlyGoal(
                                title: title,
                                description: description.isEmpty ? nil : description,
                                year: year
                            )
                        } else {
                            await viewModel.createQuarterlyGoal(
                                title: title,
                                description: description.isEmpty ? nil : description,
                                year: year,
                                quarter: quarter,
                                parentGoalId: nil
                            )
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

// MARK: - Preview

#Preview {
    GoalListView()
        .environmentObject(AppState())
}
