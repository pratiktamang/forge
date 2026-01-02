import SwiftUI
import GRDB

private typealias AsyncTask = _Concurrency.Task

struct ProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project

    @State private var title: String
    @State private var description: String
    @State private var selectedInitiativeId: String?
    @State private var status: ProjectStatus
    @State private var initiatives: [InitiativeWithGoal] = []
    @State private var isSaving = false

    private let projectRepository = ProjectRepository()
    private let initiativeRepository = InitiativeRepository()

    struct InitiativeWithGoal: Identifiable {
        let initiative: Initiative
        let goalTitle: String?
        var id: String { initiative.id }

        var displayName: String {
            if let goalTitle = goalTitle {
                return "\(initiative.title) (\(goalTitle))"
            }
            return initiative.title
        }
    }

    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _description = State(initialValue: project.description ?? "")
        _selectedInitiativeId = State(initialValue: project.initiativeId)
        _status = State(initialValue: project.status)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Edit Project")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty || isSaving)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                }

                Section("Link to Goal") {
                    Picker("Initiative", selection: $selectedInitiativeId) {
                        Text("None").tag(nil as String?)
                        ForEach(initiatives) { item in
                            Text(item.displayName).tag(item.initiative.id as String?)
                        }
                    }

                    if initiatives.isEmpty {
                        Text("No initiatives available. Create goals and initiatives first.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: 400)
        .task {
            await loadInitiatives()
        }
    }

    private func loadInitiatives() async {
        do {
            let allInitiatives = try await initiativeRepository.fetchActive()
            let goalRepository = GoalRepository()

            var items: [InitiativeWithGoal] = []
            for initiative in allInitiatives {
                var goalTitle: String? = nil
                if let goalId = initiative.goalId {
                    goalTitle = try await goalRepository.fetch(id: goalId)?.title
                }
                items.append(InitiativeWithGoal(initiative: initiative, goalTitle: goalTitle))
            }
            initiatives = items
        } catch {
            print("Failed to load initiatives: \(error)")
        }
    }

    private func save() {
        isSaving = true
        AsyncTask {
            var updatedProject = project
            updatedProject.title = title
            updatedProject.description = description.isEmpty ? nil : description
            updatedProject.initiativeId = selectedInitiativeId
            updatedProject.status = status

            do {
                try await projectRepository.save(updatedProject)
                dismiss()
            } catch {
                print("Failed to save project: \(error)")
            }
            isSaving = false
        }
    }
}
