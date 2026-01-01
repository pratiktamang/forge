import SwiftUI

struct DailyNoteListView: View {
    @StateObject private var viewModel = DailyNoteViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showingCalendar = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation header
            dateNavigationHeader

            Divider()

            // Content
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                dailyNoteContent
            }
        }
        .navigationTitle("Daily Notes")
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationHeader: some View {
        HStack(spacing: 16) {
            // Previous day
            Button(action: {
                Task { await viewModel.navigateToYesterday() }
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            // Date display / Calendar picker
            Button(action: { showingCalendar.toggle() }) {
                VStack(spacing: 2) {
                    Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.selectedDate.formatted(.dateTime.month().day().year()))
                        .font(.headline)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingCalendar) {
                calendarPicker
            }

            // Next day
            Button(action: {
                Task { await viewModel.navigateToTomorrow() }
            }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)

            Spacer()

            // Today button
            if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                Button("Today") {
                    Task { await viewModel.navigateToToday() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }

    // MARK: - Calendar Picker

    private var calendarPicker: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { viewModel.selectedDate },
                    set: { date in
                        Task { await viewModel.selectDate(date) }
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            Divider()

            // Quick navigation
            HStack(spacing: 12) {
                Button("Yesterday") {
                    Task {
                        await viewModel.navigateToYesterday()
                        showingCalendar = false
                    }
                }

                Button("Today") {
                    Task {
                        await viewModel.navigateToToday()
                        showingCalendar = false
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Tomorrow") {
                    Task {
                        await viewModel.navigateToTomorrow()
                        showingCalendar = false
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .padding()
        .frame(width: 300)
    }

    // MARK: - Daily Note Content

    private var dailyNoteContent: some View {
        VStack(spacing: 0) {
            if let note = viewModel.todaysNote {
                // Open in editor button
                Button(action: {
                    appState.selectedNoteId = note.id
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Open in Editor")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding()
            }

            Divider()

            // Recent daily notes list
            List {
                Section("Recent Daily Notes") {
                    ForEach(viewModel.recentDailyNotes) { note in
                        DailyNoteRow(note: note, isSelected: note.id == viewModel.todaysNote?.id)
                            .onTapGesture {
                                if let date = note.dailyDate {
                                    Task { await viewModel.selectDate(date) }
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    appState.selectedNoteId = note.id
                                }) {
                                    Label("Open in Editor", systemImage: "square.and.pencil")
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Daily Note Row

struct DailyNoteRow: View {
    let note: Note
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Date indicator
            VStack(alignment: .center, spacing: 2) {
                Text(dayOfWeek)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(dayNumber)
                    .font(.title2.weight(.semibold))

                Text(monthName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(note.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                // Preview
                if !note.content.isEmpty {
                    Text(contentPreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Stats
                HStack(spacing: 8) {
                    Label("\(note.wordCount)", systemImage: "text.word.spacing")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var dayOfWeek: String {
        guard let date = note.dailyDate else { return "" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var dayNumber: String {
        guard let date = note.dailyDate else { return "" }
        return date.formatted(.dateTime.day())
    }

    private var monthName: String {
        guard let date = note.dailyDate else { return "" }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private var contentPreview: String {
        let stripped = note.content
            .replacingOccurrences(of: #"^#+\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: note.title, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(stripped.prefix(100))
    }
}

// MARK: - Preview

#Preview {
    DailyNoteListView()
        .environmentObject(AppState())
}
