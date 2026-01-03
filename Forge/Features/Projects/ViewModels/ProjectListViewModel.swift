import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class ProjectListViewModel: ObservableObject {
    @Published var projectsWithCounts: [ProjectRepository.ProjectWithTaskCount] = []
    @Published var isLoading = false
    @Published var error: Error?

    var projects: [Project] {
        projectsWithCounts.map { $0.project }
    }

    private let repository: ProjectRepository
    private var cancellable: AnyCancellable?

    init(repository: ProjectRepository = ProjectRepository()) {
        self.repository = repository
    }

    func startObserving() {
        cancellable = repository.observeActiveWithTaskCounts()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] projectsWithCounts in
                    self?.projectsWithCounts = projectsWithCounts
                }
            )
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }

    func taskCount(for projectId: String) -> Int {
        projectsWithCounts.first { $0.project.id == projectId }?.taskCount ?? 0
    }

    func completedCount(for projectId: String) -> Int {
        projectsWithCounts.first { $0.project.id == projectId }?.completedCount ?? 0
    }

    func createProject(title: String) async {
        let project = Project(title: title)
        do {
            try await repository.save(project)
        } catch {
            self.error = error
        }
    }

    func updateProject(_ project: Project) async {
        do {
            try await repository.save(project)
        } catch {
            self.error = error
        }
    }

    func deleteProject(_ project: Project) async {
        do {
            try await repository.delete(project)
        } catch {
            self.error = error
        }
    }

    func duplicateProject(_ project: Project) async {
        var newProject = project
        newProject.id = UUID().uuidString
        newProject.title = "\(project.title) (Copy)"
        newProject.createdAt = Date()
        newProject.updatedAt = Date()
        do {
            try await repository.save(newProject)
        } catch {
            self.error = error
        }
    }
}
