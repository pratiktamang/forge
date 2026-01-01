import SwiftUI
import AppKit

private typealias AsyncTask = _Concurrency.Task

struct ActivityDashboardView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @State private var showingAppPicker: TrackedApp?

    var body: some View {
        VStack(spacing: 0) {
            // Date navigation header
            dateNavigationHeader

            Divider()

            if viewModel.isLoading && viewModel.topApps.isEmpty {
                loadingView
            } else if viewModel.topApps.isEmpty && !viewModel.isMonitoringEnabled {
                enableMonitoringView
            } else if viewModel.topApps.isEmpty {
                noDataView
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Productivity score
                        productivityScoreSection

                        // Time breakdown
                        timeBreakdownSection

                        // Top apps
                        topAppsSection
                    }
                    .padding()
                }
            }

            Divider()

            // Monitoring toggle footer
            monitoringFooter
        }
        .navigationTitle("Activity")
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
        .sheet(item: $showingAppPicker) { app in
            AppCategoryPicker(app: app, viewModel: viewModel)
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationHeader: some View {
        HStack {
            Button(action: { viewModel.previousDay() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(dateTitle)
                    .font(.headline)
                if !viewModel.isToday {
                    Button("Go to Today") {
                        viewModel.goToToday()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }

            Spacer()

            Button(action: { viewModel.nextDay() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isToday)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var dateTitle: String {
        if viewModel.isToday {
            return "Today"
        } else if Calendar.current.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: viewModel.selectedDate)
        }
    }

    // MARK: - Productivity Score

    private var productivityScoreSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)

                // Progress ring
                Circle()
                    .trim(from: 0, to: Double(viewModel.productivityScore) / 100.0)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.productivityScore)

                // Center text
                VStack(spacing: 4) {
                    Text("\(viewModel.productivityScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Productivity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 140, height: 140)

            Text(viewModel.totalTimeFormatted)
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Total tracked time")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical)
    }

    private var scoreColor: Color {
        let score = viewModel.productivityScore
        if score >= 70 {
            return Color(hex: AppCategory.productive.color)
        } else if score >= 40 {
            return .orange
        } else {
            return Color(hex: AppCategory.distracting.color)
        }
    }

    // MARK: - Time Breakdown

    private var timeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Breakdown")
                .font(.headline)

            // Time bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    if let stats = viewModel.dailyStats, stats.totalTrackedSeconds > 0 {
                        let total = Double(stats.totalTrackedSeconds)

                        Rectangle()
                            .fill(Color(hex: AppCategory.productive.color))
                            .frame(width: geometry.size.width * CGFloat(stats.productiveSeconds) / CGFloat(total))

                        Rectangle()
                            .fill(Color(hex: AppCategory.neutral.color))
                            .frame(width: geometry.size.width * CGFloat(stats.neutralSeconds) / CGFloat(total))

                        Rectangle()
                            .fill(Color(hex: AppCategory.distracting.color))
                            .frame(width: geometry.size.width * CGFloat(stats.distractingSeconds) / CGFloat(total))
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 20)

            // Legend
            HStack(spacing: 24) {
                categoryLegend(
                    category: .productive,
                    duration: viewModel.productiveTimeFormatted
                )
                categoryLegend(
                    category: .neutral,
                    duration: viewModel.neutralTimeFormatted
                )
                categoryLegend(
                    category: .distracting,
                    duration: viewModel.distractingTimeFormatted
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func categoryLegend(category: AppCategory, duration: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(duration)
                    .font(.callout)
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Top Apps

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Apps")
                .font(.headline)

            ForEach(viewModel.topApps, id: \.0.id) { app, duration in
                AppRowView(
                    app: app,
                    duration: viewModel.formatAppDuration(duration),
                    onCategoryTap: {
                        showingAppPicker = app
                    }
                )
            }
        }
    }

    // MARK: - Empty States

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading activity data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enableMonitoringView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Activity Tracking")
                .font(.headline)

            Text("Enable monitoring to track your\napp usage and productivity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { viewModel.toggleMonitoring() }) {
                Label("Enable Monitoring", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No activity data")
                .font(.headline)

            Text("Activity will be recorded as you\nuse other applications")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var monitoringFooter: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isMonitoringEnabled ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(viewModel.isMonitoringEnabled ? "Monitoring active" : "Monitoring paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.isMonitoringEnabled },
                set: { _ in viewModel.toggleMonitoring() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - App Row View

struct AppRowView: View {
    let app: TrackedApp
    let duration: String
    let onCategoryTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            appIcon

            // App name
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Duration
            Text(duration)
                .font(.callout)
                .foregroundColor(.secondary)
                .monospacedDigit()

            // Category badge
            Button(action: onCategoryTap) {
                Text(app.category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: app.category.color))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = getAppIcon(bundleId: app.bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 32, height: 32)
        } else {
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
        }
    }

    private func getAppIcon(bundleId: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - Preview

#Preview {
    ActivityDashboardView()
        .frame(width: 400, height: 700)
}
