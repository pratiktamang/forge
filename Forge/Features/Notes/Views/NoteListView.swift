import SwiftUI

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

struct NoteListView: View {
    @StateObject private var viewModel = NoteListViewModel()
    @EnvironmentObject var appState: AppState
    @State private var isCreatingNote = false
    @State private var newNoteTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar

            // Content
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.searchQuery.isEmpty {
                searchResultsList
            } else {
                notesList
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { isCreatingNote = true }) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $isCreatingNote) {
            newNoteSheet
        }
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search notes...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            // Pinned section
            if !viewModel.pinnedNotes.isEmpty {
                Section("Pinned") {
                    ForEach(viewModel.pinnedNotes) { note in
                        NoteRowView(note: note)
                            .onTapGesture {
                                appState.selectedNoteId = note.id
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                    }
                }
            }

            // All notes section
            Section("All Notes") {
                if viewModel.notes.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.notes.filter { !$0.isPinned }) { note in
                        NoteRowView(note: note)
                            .onTapGesture {
                                appState.selectedNoteId = note.id
                            }
                            .contextMenu {
                                noteContextMenu(note)
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List {
            if viewModel.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No results for \"\(viewModel.searchQuery)\"")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                Section("Search Results (\(viewModel.searchResults.count))") {
                    ForEach(viewModel.searchResults) { note in
                        NoteRowView(note: note, highlightQuery: viewModel.searchQuery)
                            .onTapGesture {
                                appState.selectedNoteId = note.id
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No notes yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Create your first note to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Create Note") {
                isCreatingNote = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func noteContextMenu(_ note: Note) -> some View {
        Button(action: {
            AsyncTask { await viewModel.togglePin(note) }
        }) {
            Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
        }

        Divider()

        Button(role: .destructive, action: {
            AsyncTask { await viewModel.deleteNote(note) }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - New Note Sheet

    private var newNoteSheet: some View {
        VStack(spacing: 16) {
            Text("New Note")
                .font(.headline)

            TextField("Note title", text: $newNoteTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isCreatingNote = false
                    newNoteTitle = ""
                }

                Spacer()

                Button("Create") {
                    AsyncTask {
                        if let note = await viewModel.createNote(title: newNoteTitle) {
                            appState.selectedNoteId = note.id
                        }
                        newNoteTitle = ""
                        isCreatingNote = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newNoteTitle.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    let note: Note
    var highlightQuery: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: note.isDailyNote ? "calendar.day.timeline.left" : "doc.text")
                .foregroundColor(note.isPinned ? .orange : .accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // Title
                HStack {
                    Text(note.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                // Preview and metadata
                HStack(spacing: 8) {
                    if !note.content.isEmpty {
                        Text(contentPreview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var contentPreview: String {
        let stripped = note.content
            .replacingOccurrences(of: #"#+\s*"#, with: "", options: .regularExpression) // Remove headers
            .replacingOccurrences(of: #"\[\[([^\]]+)\]\]"#, with: "$1", options: .regularExpression) // Show link text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let firstLine = stripped.components(separatedBy: .newlines).first ?? ""
        return String(firstLine.prefix(60))
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.updatedAt) {
            return note.updatedAt.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(note.updatedAt) {
            return "Yesterday"
        } else {
            return note.updatedAt.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Preview

#Preview {
    NoteListView()
        .environmentObject(AppState())
}
