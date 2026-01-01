import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var taskTitle = ""
    @State private var selectedProjectId: String?
    @State private var dueDate: Date?
    @State private var showDatePicker = false
    @FocusState private var isFocused: Bool

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
                    Divider()
                    // TODO: Add project list
                } label: {
                    HStack {
                        Image(systemName: selectedProjectId == nil ? "tray" : "folder")
                        Text(selectedProjectId == nil ? "Inbox" : "Project")
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
                    Text("Add")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }

            // Keyboard hint
            Text("Press ⌘↵ to save")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            isFocused = true
        }
    }

    private func saveTask() {
        guard !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let task = Task(
            title: taskTitle,
            projectId: selectedProjectId,
            dueDate: dueDate
        )

        // TODO: Save to database
        print("Created task: \(task.title)")

        // Reset and close
        taskTitle = ""
        dueDate = nil
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    QuickCaptureView()
}
