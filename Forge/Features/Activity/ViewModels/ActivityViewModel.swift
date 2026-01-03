import SwiftUI
import Combine
import GRDB

private typealias AsyncTask = _Concurrency.Task

enum ActivityMonitoringError: LocalizedError {
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Enable Accessibility access for Forge in System Settings → Privacy & Security → Accessibility to start activity tracking."
        }
    }
}

@MainActor
final class ActivityViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedDate: Date = Date()
    @Published var dailyStats: DailyProductivity?
    @Published var topApps: [(TrackedApp, Int)] = []
    @Published var activityLogs: [ActivityLog] = []
    @Published var isLoading = false
    @Published var error: Error?

    @AppStorage(ActivityMonitor.isEnabledKey) var isMonitoringEnabled = false

    // MARK: - Computed Properties

    var productivityScore: Int {
        Int(dailyStats?.productivityScore ?? 0)
    }

    var totalTimeFormatted: String {
        dailyStats?.formattedTotalTime ?? "0m"
    }

    var productiveTimeFormatted: String {
        dailyStats?.formattedProductiveTime ?? "0m"
    }

    var distractingTimeFormatted: String {
        dailyStats?.formattedDistractingTime ?? "0m"
    }

    var neutralTimeFormatted: String {
        formatDuration(dailyStats?.neutralSeconds ?? 0)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // MARK: - Dependencies

    private let repository: ActivityRepository
    private let monitor: ActivityMonitor
    private var logsCancellable: AnyCancellable?

    // MARK: - Init

    init(repository: ActivityRepository = ActivityRepository(), monitor: ActivityMonitor = .shared) {
        self.repository = repository
        self.monitor = monitor
    }

    // MARK: - Observation

    func startObserving() {
        loadData()
        observeLogs()

        // Start monitoring if enabled
        if isMonitoringEnabled {
            if monitor.hasAccessibilityPermission(promptIfNeeded: false) {
                monitor.startMonitoring()
            } else {
                isMonitoringEnabled = false
            }
        }
    }

    func stopObserving() {
        logsCancellable?.cancel()
        logsCancellable = nil
    }

    // MARK: - Actions

    func toggleMonitoring() {
        isMonitoringEnabled.toggle()

        if isMonitoringEnabled {
            guard monitor.hasAccessibilityPermission(promptIfNeeded: true) else {
                isMonitoringEnabled = false
                error = ActivityMonitoringError.accessibilityDenied
                return
            }
            monitor.startMonitoring()
        } else {
            monitor.stopMonitoring()
        }
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        loadData()
        observeLogs()
    }

    func goToToday() {
        selectDate(Date())
    }

    func previousDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    func nextDay() {
        if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectDate(newDate)
        }
    }

    func updateAppCategory(_ app: TrackedApp, category: AppCategory) async {
        do {
            try await repository.updateAppCategory(app, category: category)
            loadData() // Refresh stats after category change
        } catch {
            self.error = error
        }
    }

    func setAppIgnored(_ app: TrackedApp, ignored: Bool) async {
        do {
            try await repository.setAppIgnored(app, ignored: ignored)
            loadData()
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    private func loadData() {
        isLoading = true

        AsyncTask {
            do {
                // Fetch top apps with durations
                let appDurations = try await repository.fetchAppDurationsForDate(selectedDate)
                self.topApps = appDurations

                // Calculate daily productivity
                let stats = try await repository.calculateDailyProductivity(for: selectedDate)
                self.dailyStats = stats

                self.isLoading = false
            } catch {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func observeLogs() {
        logsCancellable?.cancel()
        logsCancellable = repository.observeLogsForDate(selectedDate)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] logs in
                    self?.activityLogs = logs
                    // Refresh stats when logs change
                    self?.loadData()
                }
            )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Helper Extension

extension ActivityViewModel {
    func formatAppDuration(_ seconds: Int) -> String {
        formatDuration(seconds)
    }
}
