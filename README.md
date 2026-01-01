# Forge

> *Craft your productivity system*

A macOS productivity app combining goal planning, GTD task management, Kanban boards, note-taking with Vim mode, and activity tracking.

## Tech Stack

- **SwiftUI** - 3-column NavigationSplitView layout
- **GRDB.swift** - SQLite with reactive ValueObservation
- **XcodeGen** - Project generation from `project.yml`

## Building

```bash
# Generate Xcode project (required after adding files or modifying project.yml)
xcodegen generate

# Open in Xcode
open Forge.xcodeproj

# Or build from command line
xcodebuild -scheme Forge -destination 'platform=macOS' build
```

## Project Structure

```
Forge/
├── App/
│   ├── ForgeApp.swift          # Main entry, database init
│   ├── AppDelegate.swift       # Menu bar integration
│   └── AppState.swift          # Global navigation state
├── Core/
│   ├── Database/
│   │   ├── AppDatabase.swift   # SQLite setup & migrations
│   │   └── Repositories/       # Data access (TaskRepository, NoteRepository, etc.)
│   └── Models/                 # Task, Note, Goal, Project, Board, Habit, etc.
├── Features/
│   ├── Tasks/                  # Task list, detail views
│   ├── Goals/                  # Goals & initiatives hierarchy
│   ├── Kanban/                 # Board, column, card views
│   └── Notes/                  # Markdown editor with Vim mode
├── Shared/
│   ├── Navigation/             # MainNavigationView, SidebarView
│   └── Components/             # CommandPalette (Cmd+K), QuickCapture
└── Resources/
```

## Implementation Status

### Done
- [x] SQLite database with full schema (goals, initiatives, projects, tasks, boards, notes, habits, activity)
- [x] Repository pattern for all data access
- [x] 3-column navigation with sidebar sections
- [x] Command palette (Cmd+K)
- [x] Menu bar quick capture
- [x] Task management: Inbox, Today, Upcoming, Flagged, Completed filters
- [x] Task detail: due/defer dates, priority, estimates, subtasks
- [x] Goal hierarchy: Yearly → Quarterly → Initiatives → Projects
- [x] Kanban boards with columns and WIP limits
- [x] Notes with wiki-style [[links]]
- [x] Daily notes with calendar picker
- [x] Vim mode: Normal, Insert, Visual, Command modes
- [x] Vim motions: h/j/k/l, w/b/e, 0/$, gg/G, f/F/t/T
- [x] Vim operators: d, c, y, p
- [x] Habit tracking: daily/weekly/custom frequency, streak calculations
- [x] Habit stats: current streak, longest streak, 30-day completion rate
- [x] Habit calendar: visual completion history with month navigation
- [x] Calendar view: month grid with task indicators and day selection
- [x] Calendar task list: view and manage tasks by date
- [x] Activity tracking: app usage monitoring with productivity scoring
- [x] Activity dashboard: daily stats, time breakdown, top apps
- [x] App categorization: productive/neutral/distracting classification
- [x] Weekly review: 8-step guided review process
- [x] Weekly review reflection: wins, challenges, lessons, next week focus
- [x] Weekly stats: tasks completed/created, habit completion rate

### TODO
- [ ] Custom perspectives (saved filters)
- [ ] iCloud sync

## Architecture Notes

- **MVVM + Repository**: Views → ViewModels → Repositories → AppDatabase
- **Reactive**: GRDB ValueObservation streams updates to ViewModels
- **Task naming**: Swift's `Task` conflicts with our model - use `AsyncTask` typealias for concurrency
- **Database init**: Happens in `ForgeApp.init()` before views load

## Requirements

- macOS 14.0+
- Xcode 15.0+

## License

MIT
