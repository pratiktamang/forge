import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct WeeklyReviewView: View {
    @StateObject private var viewModel = WeeklyReviewViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            reviewHeader

            Divider()

            // Step content
            if viewModel.isLoading && viewModel.review == nil {
                loadingView
            } else if viewModel.review?.isCompleted == true {
                completedView
            } else {
                stepContent
            }

            Divider()

            // Navigation footer
            if viewModel.review?.isCompleted != true {
                navigationFooter
            }
        }
        .navigationTitle("Weekly Review")
        .onAppear {
            viewModel.startReview()
        }
    }

    // MARK: - Header

    private var reviewHeader: some View {
        VStack(spacing: 12) {
            Text(viewModel.weekRangeString)
                .font(.headline)
                .foregroundColor(.secondary)

            // Step indicators
            HStack(spacing: 4) {
                ForEach(ReviewStep.allCases, id: \.self) { step in
                    stepIndicator(step)
                }
            }

            // Current step title
            VStack(spacing: 4) {
                Text(viewModel.currentStep.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(viewModel.currentStep.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func stepIndicator(_ step: ReviewStep) -> some View {
        let isActive = step == viewModel.currentStep
        let isPast = step.rawValue < viewModel.currentStep.rawValue

        return Circle()
            .fill(isPast ? Color.green : (isActive ? Color.accentColor : Color.secondary.opacity(0.3)))
            .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
            .animation(.easeInOut(duration: 0.2), value: viewModel.currentStep)
            .onTapGesture {
                if isPast {
                    viewModel.goToStep(step)
                }
            }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch viewModel.currentStep {
                case .inbox:
                    InboxStepView(viewModel: viewModel)
                case .completed:
                    CompletedStepView(viewModel: viewModel)
                case .projects:
                    ProjectsStepView(viewModel: viewModel)
                case .goals:
                    GoalsStepView(viewModel: viewModel)
                case .habits:
                    HabitsStepView(viewModel: viewModel)
                case .reflection:
                    ReflectionStepView(viewModel: viewModel)
                case .planning:
                    PlanningStepView(viewModel: viewModel)
                case .summary:
                    SummaryStepView(viewModel: viewModel)
                }
            }
            .padding()
        }
    }

    // MARK: - Navigation Footer

    private var navigationFooter: some View {
        HStack {
            if viewModel.canGoBack {
                Button(action: { viewModel.goToPreviousStep() }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.isLastStep {
                Button(action: { viewModel.completeReview() }) {
                    Label("Complete Review", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: { viewModel.goToNextStep() }) {
                    Label("Continue", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading review...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Review Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("Great job completing your weekly review.\nSee you next week!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let review = viewModel.review {
                VStack(alignment: .leading, spacing: 12) {
                    if let wins = review.wins, !wins.isEmpty {
                        reviewSection("Wins", content: wins, icon: "star.fill", color: .yellow)
                    }
                    if let focus = review.nextWeekFocus, !focus.isEmpty {
                        reviewSection("Next Week Focus", content: focus, icon: "target", color: .accentColor)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Start New Review") {
                viewModel.startReview()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reviewSection(_ title: String, content: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Step Views

struct InboxStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.inboxTasks.isEmpty {
                emptyState("Inbox Zero!", "Great job keeping your inbox clear.", icon: "tray.fill", color: .green)
            } else {
                Text("\(viewModel.inboxTasks.count) items to process")
                    .font(.headline)
                    .foregroundColor(.secondary)

                ForEach(viewModel.inboxTasks) { task in
                    InboxTaskRow(task: task, viewModel: viewModel)
                }
            }
        }
    }
}

struct InboxTaskRow: View {
    let task: Task
    @ObservedObject var viewModel: WeeklyReviewViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(task.title)
                    .font(.callout)

                Spacer()

                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                HStack(spacing: 8) {
                    ForEach([TaskStatus.next, .waiting, .someday, .completed], id: \.self) { status in
                        Button(status.displayName) {
                            AsyncTask { await viewModel.processInboxTask(task, status: status) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CompletedStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.completedTasks.isEmpty {
                emptyState("No completions yet", "Complete some tasks to see them here.", icon: "checkmark.circle", color: .secondary)
            } else {
                Text("\(viewModel.completedTasks.count) tasks completed this week!")
                    .font(.headline)
                    .foregroundColor(.green)

                ForEach(viewModel.completedTasks) { task in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(task.title)
                            .font(.callout)
                        Spacer()
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct ProjectsStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.stalledProjects.isEmpty {
                emptyState("All projects active!", "No stalled projects found.", icon: "folder.fill", color: .green)
            } else {
                Text("\(viewModel.stalledProjects.count) projects need attention")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("These projects have no completed tasks in the last 7 days:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(viewModel.stalledProjects) { project in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(project.title)
                            .font(.callout)
                        Spacer()
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct GoalsStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.activeGoals.isEmpty {
                emptyState("No active goals", "Set some goals to track your progress.", icon: "target", color: .secondary)
            } else {
                ForEach(viewModel.activeGoals) { goal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(goal.title)
                                .font(.callout)
                                .fontWeight(.medium)
                            Spacer()
                            Text(goal.displayPeriod)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: goal.progress / 100)
                            .tint(goal.progress >= 75 ? .green : (goal.progress >= 50 ? .orange : .accentColor))

                        Text("\(Int(goal.progress))% complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct HabitsStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(spacing: 20) {
            if let stats = viewModel.habitStats {
                // Completion rate ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: stats.completionRate / 100)
                        .stroke(rateColor(stats.completionRate), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Text("\(Int(stats.completionRate))%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Completion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 140, height: 140)

                // Stats
                HStack(spacing: 24) {
                    statItem("Habits", value: "\(stats.totalHabits)", icon: "repeat")
                    statItem("Completed", value: "\(stats.completionsThisWeek)", icon: "checkmark")
                    statItem("Target", value: "\(stats.possibleCompletions)", icon: "target")
                }
            } else {
                emptyState("No habit data", "Start tracking habits to see your stats.", icon: "repeat", color: .secondary)
            }
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        if rate >= 80 { return .green }
        if rate >= 60 { return .orange }
        return .red
    }

    private func statItem(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ReflectionStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            reflectionField(
                "What were your wins this week?",
                text: $viewModel.wins,
                icon: "star.fill",
                color: .yellow
            )

            reflectionField(
                "What challenges did you face?",
                text: $viewModel.challenges,
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )

            reflectionField(
                "What did you learn?",
                text: $viewModel.lessons,
                icon: "lightbulb.fill",
                color: .accentColor
            )
        }
    }

    private func reflectionField(_ title: String, text: Binding<String>, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)

            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct PlanningStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("What will you focus on next week?", systemImage: "target")
                .font(.headline)
                .foregroundColor(.accentColor)

            Text("Set your intention for the coming week. What's the one thing that would make it a success?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $viewModel.nextWeekFocus)
                .font(.body)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SummaryStepView: View {
    @ObservedObject var viewModel: WeeklyReviewViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Week in Review")
                .font(.title2)
                .fontWeight(.bold)

            if let stats = viewModel.weeklyStats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    summaryCard("Completed", value: "\(stats.tasksCompleted)", icon: "checkmark.circle.fill", color: .green)
                    summaryCard("Created", value: "\(stats.tasksCreated)", icon: "plus.circle.fill", color: .blue)
                    summaryCard("Inbox", value: "\(stats.inboxCount)", icon: "tray.fill", color: stats.inboxCount > 0 ? .orange : .green)
                    summaryCard("Overdue", value: "\(stats.overdueTasks)", icon: "exclamationmark.circle.fill", color: stats.overdueTasks > 0 ? .red : .green)
                }
            }

            if let habitStats = viewModel.habitStats {
                HStack {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundColor(.purple)
                    Text("Habits: \(Int(habitStats.completionRate))% completion rate")
                        .font(.callout)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !viewModel.nextWeekFocus.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next Week Focus", systemImage: "target")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text(viewModel.nextWeekFocus)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func summaryCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper

private func emptyState(_ title: String, _ subtitle: String, icon: String, color: Color) -> some View {
    VStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 40))
            .foregroundColor(color)
        Text(title)
            .font(.headline)
        Text(subtitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
}

// MARK: - Preview

#Preview {
    WeeklyReviewView()
        .frame(width: 500, height: 700)
}
