import SwiftUI
import AppKit

private typealias AsyncTask = _Concurrency.Task

struct AppCategoryPicker: View {
    let app: TrackedApp
    @ObservedObject var viewModel: ActivityViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // App info header
            VStack(spacing: 12) {
                appIcon

                Text(app.appName)
                    .font(.headline)

                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            Divider()

            // Category selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Category")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(AppCategory.allCases, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal)

            Divider()

            // Ignore toggle
            Toggle(isOn: Binding(
                get: { app.isIgnored },
                set: { newValue in
                    AsyncTask { await viewModel.setAppIgnored(app, ignored: newValue) }
                    dismiss()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ignore this app")
                        .font(.callout)
                    Text("Activity won't be tracked for this app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Spacer()

            // Cancel button
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
        .frame(width: 300, height: 400)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = getAppIcon(bundleId: app.bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 64, height: 64)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .frame(width: 64, height: 64)
        }
    }

    private func categoryButton(_ category: AppCategory) -> some View {
        Button(action: {
            AsyncTask { await viewModel.updateAppCategory(app, category: category) }
            dismiss()
        }) {
            HStack {
                Circle()
                    .fill(Color(hex: category.color))
                    .frame(width: 12, height: 12)

                Text(category.displayName)
                    .foregroundColor(.primary)

                Spacer()

                if app.category == category {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(app.category == category
                          ? Color.accentColor.opacity(0.1)
                          : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(app.category == category
                            ? Color.accentColor
                            : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    AppCategoryPicker(
        app: TrackedApp(
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            category: .neutral
        ),
        viewModel: ActivityViewModel()
    )
}
