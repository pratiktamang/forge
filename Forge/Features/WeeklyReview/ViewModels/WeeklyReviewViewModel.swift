import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class WeeklyReviewViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentStep: ReviewStep = .inbox
    @Published var review: WeeklyReview?
    @Published var isLoading = false
    @Published var error: Error?

    // Step-specific data
    @Published var inboxTasks: [Task] = []
    @Published var completedTasks: [Task] = []
    @Published var stalledProjects: [Project] = []
    @Published var activeGoals: [Goal] = []
    @Published var weeklyStats: WeeklyStats?
    @Published var habitStats: HabitWeeklyStats?

    // Reflection fields (editable)
    @Published var wins: String = ""
    @Published var challenges: String = ""
    @Published var lessons: String = ""
    @Published var nextWeekFocus: String = ""

    // MARK: - Computed Properties

    var progress: Double {
        let currentIndex = ReviewStep.allCases.firstIndex(of: currentStep) ?? 0
        return Double(currentIndex) / Double(ReviewStep.allCases.count - 1)
    }

    var canGoBack: Bool {
        currentStep.previous != nil
    }

    var canGoForward: Bool {
        currentStep.next != nil
    }

    var isLastStep: Bool {
        currentStep == .summary
    }

    var weekStart: Date {
        Calendar.current.startOfWeek(for: Date())
    }

    var weekRangeString: String {
        review?.weekRangeString ?? ""
    }

    // MARK: - Dependencies

    private let repository: WeeklyReviewRepository
    private let taskRepository: TaskRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: WeeklyReviewRepository = WeeklyReviewRepository(),
         taskRepository: TaskRepository = TaskRepository()) {
        self.repository = repository
        self.taskRepository = taskRepository
    }

    // MARK: - Lifecycle

    func startReview() {
        isLoading = true
        AsyncTask {
            do {
                // Get or create review for current week
                let review = try await repository.getOrCreateForWeek(Date())
                self.review = review

                // Pre-populate reflection fields
                self.wins = review.wins ?? ""
                self.challenges = review.challenges ?? ""
                self.lessons = review.lessons ?? ""
                self.nextWeekFocus = review.nextWeekFocus ?? ""

                // Load initial data
                await self.loadDataForCurrentStep()

                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let nextStep = currentStep.next else { return }

        // Save current step data if needed
        saveCurrentStepData()

        currentStep = nextStep
        AsyncTask { await loadDataForCurrentStep() }
    }

    func goToPreviousStep() {
        guard let previousStep = currentStep.previous else { return }
        currentStep = previousStep
        AsyncTask { await loadDataForCurrentStep() }
    }

    func goToStep(_ step: ReviewStep) {
        saveCurrentStepData()
        currentStep = step
        AsyncTask { await loadDataForCurrentStep() }
    }

    // MARK: - Complete Review

    func completeReview() {
        guard var review = review else { return }

        saveCurrentStepData()

        review.wins = wins.isEmpty ? nil : wins
        review.challenges = challenges.isEmpty ? nil : challenges
        review.lessons = lessons.isEmpty ? nil : lessons
        review.nextWeekFocus = nextWeekFocus.isEmpty ? nil : nextWeekFocus
        review.tasksCompleted = weeklyStats?.tasksCompleted ?? 0
        review.tasksCreated = weeklyStats?.tasksCreated ?? 0
        review.habitsCompletionRate = habitStats?.completionRate
        review.complete()

        AsyncTask {
            do {
                try await repository.save(review)
                self.review = review
            } catch {
                self.error = error
            }
        }
    }

    // MARK: - Private Methods

    private func loadDataForCurrentStep() async {
        isLoading = true

        do {
            switch currentStep {
            case .inbox:
                inboxTasks = try await taskRepository.fetchInbox()

            case .completed:
                completedTasks = try await repository.fetchCompletedTasks(weekStart: weekStart)

            case .projects:
                stalledProjects = try await repository.fetchStalledProjects()

            case .goals:
                activeGoals = try await repository.fetchActiveGoals()

            case .habits:
                habitStats = try await repository.fetchHabitStats(weekStart: weekStart)

            case .reflection:
                // Just load existing text if any
                break

            case .planning:
                // Just load existing text if any
                break

            case .summary:
                weeklyStats = try await repository.fetchWeeklyStats(weekStart: weekStart)
                habitStats = try await repository.fetchHabitStats(weekStart: weekStart)
            }

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    private func saveCurrentStepData() {
        guard var review = review else { return }

        // Only save reflection data
        if currentStep == .reflection || currentStep == .planning {
            review.wins = wins.isEmpty ? nil : wins
            review.challenges = challenges.isEmpty ? nil : challenges
            review.lessons = lessons.isEmpty ? nil : lessons
            review.nextWeekFocus = nextWeekFocus.isEmpty ? nil : nextWeekFocus

            AsyncTask {
                try? await repository.save(review)
            }
        }
    }

    // MARK: - Task Actions

    func completeTask(_ task: Task) async {
        do {
            try await taskRepository.completeTask(task)
            inboxTasks.removeAll { $0.id == task.id }
        } catch {
            self.error = error
        }
    }

    func processInboxTask(_ task: Task, status: TaskStatus) async {
        var updated = task
        updated.status = status
        updated.updatedAt = Date()

        do {
            try await taskRepository.save(updated)
            inboxTasks.removeAll { $0.id == task.id }
        } catch {
            self.error = error
        }
    }
}
