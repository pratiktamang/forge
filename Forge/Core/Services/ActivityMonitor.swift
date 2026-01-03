import Foundation
import AppKit
import Combine
import ApplicationServices

private typealias AsyncTask = _Concurrency.Task

@MainActor
final class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()

    // MARK: - Published Properties

    @Published private(set) var isMonitoring = false
    @Published private(set) var currentApp: NSRunningApplication?

    // MARK: - Private Properties

    private let repository = ActivityRepository()
    private var currentSession: ActivitySession?
    private var workspaceObserver: Any?
    private var sleepObserver: Any?
    private var wakeObserver: Any?

    // Bundle IDs to ignore
    private let ignoredBundleIds: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.screensaver",
        "com.apple.dock",
        "com.apple.finder", // Optional: may want to track Finder
    ]

    // MARK: - Session Tracking

    private struct ActivitySession {
        let trackedApp: TrackedApp
        let startTime: Date
        let windowTitle: String?
    }

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Observe app activation
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                AsyncTask { @MainActor in
                    await self.handleAppActivation(app)
                }
            }
        }

        // Observe sleep to save current session
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            AsyncTask { @MainActor in
                await self?.saveCurrentSession()
            }
        }

        // Observe wake to start fresh
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if let frontmost = NSWorkspace.shared.frontmostApplication {
                AsyncTask { @MainActor in
                    await self.handleAppActivation(frontmost)
                }
            }
        }

        // Start tracking current frontmost app
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            AsyncTask {
                await self.handleAppActivation(frontmost)
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        // Save any current session before stopping
        AsyncTask {
            await self.saveCurrentSession()
        }

        // Remove observers
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }

        isMonitoring = false
        currentApp = nil
        currentSession = nil
    }

    // MARK: - Private Methods

    private func handleAppActivation(_ app: NSRunningApplication) async {
        guard let bundleId = app.bundleIdentifier else { return }

        // Ignore system apps and our own app
        if ignoredBundleIds.contains(bundleId) {
            return
        }

        // Ignore Forge itself
        if bundleId == Bundle.main.bundleIdentifier {
            return
        }

        // Save previous session if exists
        await saveCurrentSession()

        // Get or create tracked app
        let appName = app.localizedName ?? bundleId
        do {
            let trackedApp = try await repository.getOrCreateTrackedApp(
                bundleId: bundleId,
                appName: appName
            )

            // Skip if app is ignored
            guard !trackedApp.isIgnored else {
                currentSession = nil
                currentApp = app
                return
            }

            let windowTitle = fetchWindowTitle(for: app)

            // Start new session
            currentSession = ActivitySession(
                trackedApp: trackedApp,
                startTime: Date(),
                windowTitle: windowTitle
            )
            currentApp = app

        } catch {
            print("ActivityMonitor: Error tracking app - \(error)")
        }
    }

    private func saveCurrentSession() async {
        guard let session = currentSession else { return }

        let endTime = Date()
        let duration = Int(endTime.timeIntervalSince(session.startTime))

        // Only save if duration is at least 1 second
        guard duration >= 1 else { return }

        let log = ActivityLog(
            trackedAppId: session.trackedApp.id,
            windowTitle: session.windowTitle,
            startTime: session.startTime,
            endTime: endTime
        )

        do {
            try await repository.saveActivityLog(log)
        } catch {
            print("ActivityMonitor: Error saving activity log - \(error)")
        }

        currentSession = nil
    }
}

// MARK: - AppStorage Key

extension ActivityMonitor {
    static let isEnabledKey = "activityMonitoringEnabled"

    func hasAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        guard promptIfNeeded else {
            return false
        }

        let optionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [optionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func fetchWindowTitle(for app: NSRunningApplication) -> String? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var window: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &window)
        guard result == .success, let axWindow = window else {
            return nil
        }

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(axWindow as! AXUIElement, kAXTitleAttribute as CFString, &title)
        if titleResult == .success, let titleString = title as? String, !titleString.isEmpty {
            return titleString
        }

        return nil
    }
}
