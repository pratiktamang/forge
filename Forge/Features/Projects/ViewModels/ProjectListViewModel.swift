import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class ProjectListViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let repository: ProjectRepository
    private var cancellable: AnyCancellable?

    init(repository: ProjectRepository = ProjectRepository()) {
        self.repository = repository
    }

    func startObserving() {
        cancellable = repository.observeActive()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] projects in
                    self?.projects = projects
                }
            )
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }

    func createProject(title: String) async {
        let project = Project(title: title)
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
}
