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
    @State private var selectedColor: String?
    @State private var selectedIcon: String
    @State private var initiatives: [InitiativeWithGoal] = []
    @State private var isSaving = false

    private let projectRepository = ProjectRepository()
    private let initiativeRepository = InitiativeRepository()

    private let colorOptions: [(name: String, hex: String)] = [
        ("Blue", "007AFF"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Yellow", "FFCC00"),
        ("Green", "34C759"),
        ("Teal", "5AC8FA"),
        ("Gray", "8E8E93")
    ]

    private let iconOptions = [
        "folder", "folder.fill", "doc", "doc.fill",
        "briefcase", "briefcase.fill", "hammer", "hammer.fill",
        "wrench", "wrench.fill", "gearshape", "gearshape.fill",
        "star", "star.fill", "heart", "heart.fill",
        "bolt", "bolt.fill", "lightbulb", "lightbulb.fill",
        "book", "book.fill", "graduationcap", "graduationcap.fill",
        "music.note", "gamecontroller", "house", "house.fill",
        "cart", "cart.fill", "creditcard", "creditcard.fill"
    ]

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
        _selectedColor = State(initialValue: project.color)
        _selectedIcon = State(initialValue: project.icon ?? "folder")
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
                    HStack(spacing: 12) {
                        // Icon preview
                        ZStack {
                            Circle()
                                .fill(selectedColor != nil ? Color(hex: selectedColor!) : Color.accentColor)
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundColor(.white)
                        }

                        TextField("Title", text: $title)
                    }

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(colorOptions, id: \.hex) { option in
                                Button(action: { selectedColor = option.hex }) {
                                    Circle()
                                        .fill(Color(hex: option.hex))
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == option.hex ? 2 : 0)
                                                .padding(2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 8), spacing: 8) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .frame(width: 32, height: 32)
                                        .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(selectedIcon == icon ? .accentColor : .primary)
                            }
                        }
                    }
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
        .frame(width: 500, height: 550)
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
            updatedProject.color = selectedColor
            updatedProject.icon = selectedIcon

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
