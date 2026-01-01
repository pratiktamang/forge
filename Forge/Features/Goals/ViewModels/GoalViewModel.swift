import SwiftUI
import Combine
import GRDB

@MainActor
final class GoalViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var goalsByYear: [GoalRepository.GoalsByYear] = []
    @Published var selectedYear: Int
    @Published var isLoading = false
    @Published var error: Error?

    // MARK: - Dependencies

    private let goalRepository: GoalRepository
    private let initiativeRepository: InitiativeRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        goalRepository: GoalRepository = GoalRepository(),
        initiativeRepository: InitiativeRepository = InitiativeRepository()
    ) {
        self.goalRepository = goalRepository
        self.initiativeRepository = initiativeRepository
        self.selectedYear = Calendar.current.component(.year, from: Date())
    }

    // MARK: - Data Loading

    func loadGoals() async {
        isLoading = true
        do {
            goalsByYear = try await goalRepository.fetchGroupedByYear()
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func startObserving() {
        goalRepository.observeAll()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] goals in
                    self?.processGoals(goals)
                }
            )
            .store(in: &cancellables)
    }

    func stopObserving() {
        cancellables.removeAll()
    }

    private func processGoals(_ goals: [Goal]) {
        let grouped = Dictionary(grouping: goals) { $0.year }

        goalsByYear = grouped.keys.sorted(by: >).map { year in
            let yearGoals = grouped[year] ?? []
            let yearly = yearGoals.filter { $0.goalType == .yearly }
            let quarterly = Dictionary(grouping: yearGoals.filter { $0.goalType == .quarterly }) { $0.quarter ?? 0 }

            return GoalRepository.GoalsByYear(year: year, yearlyGoals: yearly, quarterlyGoals: quarterly)
        }

        isLoading = false
    }

    // MARK: - Actions

    func createYearlyGoal(title: String, description: String?, year: Int) async {
        let goal = Goal(
            title: title,
            description: description,
            goalType: .yearly,
            year: year
        )

        do {
            try await goalRepository.save(goal)
        } catch {
            self.error = error
        }
    }

    func createQuarterlyGoal(title: String, description: String?, year: Int, quarter: Int, parentGoalId: String?) async {
        let goal = Goal(
            title: title,
            description: description,
            goalType: .quarterly,
            year: year,
            quarter: quarter,
            parentGoalId: parentGoalId
        )

        do {
            try await goalRepository.save(goal)
        } catch {
            self.error = error
        }
    }

    func updateGoal(_ goal: Goal) async {
        do {
            try await goalRepository.save(goal)
        } catch {
            self.error = error
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await goalRepository.delete(goal)
        } catch {
            self.error = error
        }
    }

    func completeGoal(_ goal: Goal) async {
        var updated = goal
        updated.status = .completed
        updated.progress = 1.0
        await updateGoal(updated)
    }

    func archiveGoal(_ goal: Goal) async {
        var updated = goal
        updated.status = .archived
        await updateGoal(updated)
    }

    // MARK: - Helpers

    func goals(for year: Int) -> GoalRepository.GoalsByYear? {
        goalsByYear.first { $0.year == year }
    }

    func quarterlyGoals(year: Int, quarter: Int) -> [Goal] {
        goals(for: year)?.quarterlyGoals[quarter] ?? []
    }

    var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let existingYears = Set(goalsByYear.map { $0.year })
        let allYears = existingYears.union([currentYear, currentYear + 1])
        return allYears.sorted(by: >)
    }

    var currentQuarter: Int {
        let month = Calendar.current.component(.month, from: Date())
        return ((month - 1) / 3) + 1
    }
}

// MARK: - Goal Detail ViewModel

@MainActor
final class GoalDetailViewModel: ObservableObject {
    @Published var goal: Goal?
    @Published var childGoals: [Goal] = []
    @Published var initiatives: [Initiative] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let goalId: String
    private let goalRepository: GoalRepository
    private let initiativeRepository: InitiativeRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        goalId: String,
        goalRepository: GoalRepository = GoalRepository(),
        initiativeRepository: InitiativeRepository = InitiativeRepository()
    ) {
        self.goalId = goalId
        self.goalRepository = goalRepository
        self.initiativeRepository = initiativeRepository
    }

    func startObserving() {
        // Observe goal
        goalRepository.observeGoal(id: goalId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] goal in
                    self?.goal = goal
                }
            )
            .store(in: &cancellables)

        // Load related data
        Task {
            await loadRelatedData()
        }
    }

    func stopObserving() {
        cancellables.removeAll()
    }

    private func loadRelatedData() async {
        do {
            childGoals = try await goalRepository.fetchChildGoals(parentId: goalId)
            initiatives = try await initiativeRepository.fetchByGoal(goalId)
        } catch {
            self.error = error
        }
    }

    func save() async {
        guard var goal = goal else { return }
        goal.updatedAt = Date()

        do {
            try await goalRepository.save(goal)
        } catch {
            self.error = error
        }
    }

    func addInitiative(title: String, description: String?) async {
        let initiative = Initiative(
            title: title,
            description: description,
            goalId: goalId
        )

        do {
            try await initiativeRepository.save(initiative)
            await loadRelatedData()
        } catch {
            self.error = error
        }
    }

    func addQuarterlyGoal(title: String, quarter: Int) async {
        guard let goal = goal else { return }

        let quarterlyGoal = Goal(
            title: title,
            goalType: .quarterly,
            year: goal.year,
            quarter: quarter,
            parentGoalId: goalId
        )

        do {
            try await goalRepository.save(quarterlyGoal)
            await loadRelatedData()
        } catch {
            self.error = error
        }
    }

    var progress: Double {
        guard let goal = goal else { return 0 }
        if goal.goalType == .yearly && !childGoals.isEmpty {
            return childGoals.reduce(0) { $0 + $1.progress } / Double(childGoals.count)
        }
        return goal.progress
    }
}

// MARK: - Initiative ViewModel

@MainActor
final class InitiativeViewModel: ObservableObject {
    @Published var initiative: Initiative?
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let initiativeId: String
    private let initiativeRepository: InitiativeRepository
    private let projectRepository: ProjectRepository
    private var cancellables = Set<AnyCancellable>()

    init(
        initiativeId: String,
        initiativeRepository: InitiativeRepository = InitiativeRepository(),
        projectRepository: ProjectRepository = ProjectRepository()
    ) {
        self.initiativeId = initiativeId
        self.initiativeRepository = initiativeRepository
        self.projectRepository = projectRepository
    }

    func startObserving() {
        initiativeRepository.observeInitiative(id: initiativeId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] initiative in
                    self?.initiative = initiative
                }
            )
            .store(in: &cancellables)

        Task {
            await loadProjects()
        }
    }

    func stopObserving() {
        cancellables.removeAll()
    }

    private func loadProjects() async {
        do {
            projects = try await projectRepository.fetchAll().filter { $0.initiativeId == initiativeId }
        } catch {
            self.error = error
        }
    }

    func save() async {
        guard var initiative = initiative else { return }
        initiative.updatedAt = Date()

        do {
            try await initiativeRepository.save(initiative)
        } catch {
            self.error = error
        }
    }

    func createProject(title: String) async {
        let project = Project(
            title: title,
            initiativeId: initiativeId
        )

        do {
            try await projectRepository.save(project)
            await loadProjects()
        } catch {
            self.error = error
        }
    }

    var progress: Double {
        guard !projects.isEmpty else { return 0 }
        let completed = projects.filter { $0.status == .completed }.count
        return Double(completed) / Double(projects.count)
    }
}
