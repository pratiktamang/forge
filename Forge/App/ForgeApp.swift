import SwiftUI

@main
struct ForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    init() {
        // Setup database before any views are created
        do {
            try AppDatabase.shared.setup()
            #if DEBUG
            try AppDatabase.shared.seedSampleData()
            #endif
        } catch {
            print("❌ Database error: \(error)")
            fatalError("Database setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
                .background(AppTheme.windowBackground)
                .tint(AppTheme.accent)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            ForgeCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

struct ForgeCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task") {
                NotificationCenter.default.post(name: .newTask, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Note") {
                NotificationCenter.default.post(name: .newNote, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Quick Capture") {
                NotificationCenter.default.post(name: .quickCapture, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        CommandGroup(after: .toolbar) {
            Button("Command Palette") {
                NotificationCenter.default.post(name: .showCommandPalette, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}

extension Notification.Name {
    static let newTask = Notification.Name("newTask")
    static let newNote = Notification.Name("newNote")
    static let quickCapture = Notification.Name("quickCapture")
    static let showCommandPalette = Notification.Name("showCommandPalette")
}
