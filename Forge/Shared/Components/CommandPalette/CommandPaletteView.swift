import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private var filteredCommands: [Command] {
        if searchText.isEmpty {
            return Command.allCommands
        }
        return Command.allCommands.filter { command in
            command.title.localizedCaseInsensitiveContains(searchText) ||
            command.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.title3)

                TextField("Type a command or search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        executeSelectedCommand()
                    }

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results
            if filteredCommands.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No commands found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: Binding(
                        get: { selectedIndex },
                        set: { selectedIndex = $0 }
                    )) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.offset) { index, command in
                            CommandRow(command: command, isSelected: index == selectedIndex)
                                .id(index)
                                .onTapGesture {
                                    selectedIndex = index
                                    executeSelectedCommand()
                                }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }

    private func executeSelectedCommand() {
        guard let command = filteredCommands[safe: selectedIndex] else { return }
        command.action(appState)
        dismiss()
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: Command
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.icon)
                .font(.title3)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                if let description = command.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
            }

            Spacer()

            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

// MARK: - Command Model

struct Command: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let keywords: [String]
    let shortcut: String?
    let description: String?
    let action: (AppState) -> Void

    init(
        title: String,
        icon: String,
        keywords: [String] = [],
        shortcut: String? = nil,
        description: String? = nil,
        action: @escaping (AppState) -> Void
    ) {
        self.title = title
        self.icon = icon
        self.keywords = keywords
        self.shortcut = shortcut
        self.description = description
        self.action = action
    }

    static var allCommands: [Command] {
        [
            Command(
                title: "New Task",
                icon: "plus.circle",
                keywords: ["add", "create", "task", "todo"],
                shortcut: "⌘N",
                description: "Create a new task"
            ) { appState in
                NotificationCenter.default.post(name: .newTask, object: nil)
            },

            Command(
                title: "New Note",
                icon: "doc.badge.plus",
                keywords: ["add", "create", "note", "document"],
                shortcut: "⌘⇧N",
                description: "Create a new note"
            ) { appState in
                NotificationCenter.default.post(name: .newNote, object: nil)
            },

            Command(
                title: "Go to Inbox",
                icon: "tray",
                keywords: ["inbox", "navigate", "open"]
            ) { appState in
                appState.selectedSection = .inbox
            },

            Command(
                title: "Go to Today",
                icon: "star",
                keywords: ["today", "navigate", "open"]
            ) { appState in
                appState.selectedSection = .today
            },

            Command(
                title: "Go to Goals",
                icon: "target",
                keywords: ["goals", "objectives", "navigate"]
            ) { appState in
                appState.selectedSection = .goals
            },

            Command(
                title: "Go to Notes",
                icon: "doc.text",
                keywords: ["notes", "documents", "navigate"]
            ) { appState in
                appState.selectedSection = .notes
            },

            Command(
                title: "Go to Habits",
                icon: "checkmark.circle",
                keywords: ["habits", "routines", "navigate"]
            ) { appState in
                appState.selectedSection = .habits
            },

            Command(
                title: "Go to Activity",
                icon: "chart.bar",
                keywords: ["activity", "tracking", "productivity"]
            ) { appState in
                appState.selectedSection = .activity
            },

            Command(
                title: "Start Weekly Review",
                icon: "checkmark.seal",
                keywords: ["review", "weekly", "reflect"]
            ) { appState in
                appState.selectedSection = .weeklyReview
            },

            Command(
                title: "Toggle Vim Mode",
                icon: "keyboard",
                keywords: ["vim", "editor", "mode", "toggle"],
                description: "Enable or disable Vim keybindings"
            ) { appState in
                appState.isVimModeEnabled.toggle()
            },

            Command(
                title: "Quick Capture",
                icon: "bolt",
                keywords: ["quick", "capture", "fast", "add"],
                shortcut: "⌘⌥N",
                description: "Quickly add a task"
            ) { appState in
                appState.showQuickCapture = true
            }
        ]
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    CommandPaletteView()
        .environmentObject(AppState())
}
