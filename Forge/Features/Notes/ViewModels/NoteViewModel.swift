import SwiftUI
import Combine
import GRDB

// Type alias to disambiguate Swift's Task from our Task model
private typealias AsyncTask = _Concurrency.Task

@MainActor
final class NoteListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var notes: [Note] = []
    @Published var dailyNotes: [Note] = []
    @Published var pinnedNotes: [Note] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchQuery = ""
    @Published var searchResults: [Note] = []

    // MARK: - Dependencies

    private let repository: NoteRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: NoteRepository = NoteRepository()) {
        self.repository = repository
        setupSearchDebounce()
    }

    // MARK: - Search Debounce

    private func setupSearchDebounce() {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                AsyncTask {
                    await self?.performSearch(query)
                }
            }
            .store(in: &cancellables)
    }

    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try await repository.searchSimple(query: query)
        } catch {
            self.error = error
        }
    }

    // MARK: - Observation

    func startObserving() {
        // Observe all notes
        repository.observeAll()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] notes in
                    self?.notes = notes
                    self?.pinnedNotes = notes.filter { $0.isPinned }
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)

        // Observe daily notes
        repository.observeDailyNotes()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] notes in
                    self?.dailyNotes = notes
                }
            )
            .store(in: &cancellables)
    }

    func stopObserving() {
        cancellables.removeAll()
        setupSearchDebounce() // Re-setup search debounce
    }

    // MARK: - Actions

    func createNote(title: String, content: String = "") async -> Note? {
        let note = Note(title: title, content: content)

        do {
            try await repository.save(note)
            return note
        } catch {
            self.error = error
            return nil
        }
    }

    func deleteNote(_ note: Note) async {
        do {
            try await repository.delete(note)
        } catch {
            self.error = error
        }
    }

    func togglePin(_ note: Note) async {
        var updated = note
        updated.isPinned.toggle()

        do {
            try await repository.save(updated)
        } catch {
            self.error = error
        }
    }

    func getTodaysDailyNote() async -> Note? {
        do {
            return try await repository.fetchOrCreateDailyNote(date: Date())
        } catch {
            self.error = error
            return nil
        }
    }

    func getDailyNote(for date: Date) async -> Note? {
        do {
            return try await repository.fetchOrCreateDailyNote(date: date)
        } catch {
            self.error = error
            return nil
        }
    }
}

// MARK: - Note Editor ViewModel

@MainActor
final class NoteEditorViewModel: ObservableObject {
    @Published var note: Note?
    @Published var backlinks: [Note] = []
    @Published var outgoingLinks: [Note] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isSaving = false
    @Published var lastSaved: Date?

    private let noteId: String
    private let repository: NoteRepository
    private var cancellables = Set<AnyCancellable>()
    private var saveTask: AsyncTask<Void, Never>?

    init(noteId: String, repository: NoteRepository = NoteRepository()) {
        self.noteId = noteId
        self.repository = repository
    }

    // MARK: - Observation

    func startObserving() {
        isLoading = true

        // Observe note
        repository.observeNote(id: noteId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] note in
                    self?.note = note
                    self?.isLoading = false
                }
            )
            .store(in: &cancellables)

        // Observe backlinks
        repository.observeBacklinks(noteId: noteId)
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] notes in
                    self?.backlinks = notes
                }
            )
            .store(in: &cancellables)

        // Fetch outgoing links
        AsyncTask {
            await fetchOutgoingLinks()
        }
    }

    func stopObserving() {
        cancellables.removeAll()
        saveTask?.cancel()
    }

    // MARK: - Content Updates

    func updateContent(_ newContent: String) {
        note?.updateContent(newContent)
        debouncedSave()
    }

    func updateTitle(_ newTitle: String) {
        note?.title = newTitle
        note?.updatedAt = Date()
        debouncedSave()
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = AsyncTask {
            try? await AsyncTask.sleep(nanoseconds: 500_000_000) // 500ms debounce
            if !AsyncTask.isCancelled {
                await save()
            }
        }
    }

    func save() async {
        guard let note = note else { return }
        isSaving = true

        do {
            try await repository.save(note)
            lastSaved = Date()
            await fetchOutgoingLinks() // Refresh links after save
        } catch {
            self.error = error
        }

        isSaving = false
    }

    // MARK: - Links

    private func fetchOutgoingLinks() async {
        do {
            outgoingLinks = try await repository.fetchOutgoingLinks(noteId: noteId)
        } catch {
            // Ignore link fetch errors
        }
    }

    func navigateToLink(_ linkText: String) async -> Note? {
        do {
            // Try to find existing note
            if let existing = try await repository.fetchByTitle(linkText) {
                return existing
            }

            // Create new note if it doesn't exist
            let newNote = Note(title: linkText)
            try await repository.save(newNote)
            return newNote
        } catch {
            self.error = error
            return nil
        }
    }

    // MARK: - Daily Note Navigation

    func navigateToDailyNote(date: Date) async -> Note? {
        do {
            return try await repository.fetchOrCreateDailyNote(date: date)
        } catch {
            self.error = error
            return nil
        }
    }
}

// MARK: - Daily Note ViewModel

@MainActor
final class DailyNoteViewModel: ObservableObject {
    @Published var todaysNote: Note?
    @Published var recentDailyNotes: [Note] = []
    @Published var selectedDate: Date = Date()
    @Published var isLoading = false
    @Published var error: Error?

    private let repository: NoteRepository
    private var cancellable: AnyCancellable?

    init(repository: NoteRepository = NoteRepository()) {
        self.repository = repository
    }

    func startObserving() {
        isLoading = true

        // Observe daily notes
        cancellable = repository.observeDailyNotes()
            .publisher(in: AppDatabase.shared.dbQueue, scheduling: .immediate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] notes in
                    self?.recentDailyNotes = notes
                    self?.isLoading = false
                }
            )

        // Load today's note
        AsyncTask {
            await loadTodaysNote()
        }
    }

    func stopObserving() {
        cancellable?.cancel()
        cancellable = nil
    }

    func loadTodaysNote() async {
        do {
            todaysNote = try await repository.fetchOrCreateDailyNote(date: Date())
        } catch {
            self.error = error
        }
    }

    func selectDate(_ date: Date) async {
        selectedDate = date
        do {
            todaysNote = try await repository.fetchOrCreateDailyNote(date: date)
        } catch {
            self.error = error
        }
    }

    func navigateToYesterday() async {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        await selectDate(yesterday)
    }

    func navigateToTomorrow() async {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        await selectDate(tomorrow)
    }

    func navigateToToday() async {
        await selectDate(Date())
    }
}
