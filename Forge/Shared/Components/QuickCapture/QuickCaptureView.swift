import SwiftUI

private typealias AsyncTask = _Concurrency.Task

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @State private var selectedProjectId: String?
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var projects: [Project] = []
    @FocusState private var isFocused: Bool

    private let taskRepository = TaskRepository()
    private let projectRepository = ProjectRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Task input
            TextField("What needs to be done?", text: $taskTitle)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .onSubmit {
                    saveTask()
                }

            // Options row
            HStack(spacing: 12) {
                // Project picker
                Menu {
                    Button("Inbox") {
                        selectedProjectId = nil
                    }

                    if projects.isEmpty {
                        Text("No Projects")
                    } else {
                        Divider()
                        ForEach(projects) { project in
                            Button(project.title) {
                                selectedProjectId = project.id
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedProjectId == nil ? "tray" : "folder")
                        Text(selectedProjectTitle)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)

                // Due date
                Button(action: { showDatePicker.toggle() }) {
                    HStack {
                        Image(systemName: "calendar")
                        Text(dueDate?.formatted(.dateTime.month().day()) ?? "Due Date")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showDatePicker) {
                    DatePicker(
                        "Due Date",
                        selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }

                Spacer()

                // Save button
                Button(action: saveTask) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Text("Add")
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Keyboard hint
            Text("Press ⌘↵ to save")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            isFocused = true
            loadProjects()
        }
    }

    private var selectedProjectTitle: String {
        guard let id = selectedProjectId,
              let project = projects.first(where: { $0.id == id }) else {
            return "Inbox"
        }
        return project.title
    }

    private func saveTask() {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        saveError = nil

        let projectId = selectedProjectId
        let dueDate = self.dueDate

        AsyncTask {
            var task = Task(
                title: trimmed,
                projectId: projectId,
                dueDate: dueDate
            )

            if projectId != nil {
                task.status = .next
            }

            do {
                try await taskRepository.save(task)
                await MainActor.run {
                    taskTitle = ""
                    selectedProjectId = nil
                    self.dueDate = nil
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saveError = "Failed to save task. Please try again."
                    isSaving = false
                }
            }
        }
    }

    private func loadProjects() {
        AsyncTask {
            if let fetched = try? await projectRepository.fetchActive() {
                await MainActor.run {
                    projects = fetched
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QuickCaptureView()
}
