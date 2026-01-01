# Forge - Architecture

## Project Structure

```
Forge/
├── App/
│   ├── ForgeApp.swift                 # @main entry
│   ├── AppDelegate.swift              # Menu bar, global hotkeys
│   └── AppState.swift                 # Global state
├── Core/
│   ├── Database/
│   │   ├── AppDatabase.swift          # GRDB setup + migrations
│   │   └── Repositories/              # CRUD for each model
│   ├── Models/
│   │   ├── Goal.swift                 # Yearly/Quarterly goals
│   │   ├── Initiative.swift           # Major efforts
│   │   ├── Project.swift              # Task containers
│   │   ├── Task.swift                 # GTD tasks
│   │   ├── Board.swift                # Kanban boards
│   │   ├── BoardColumn.swift          # Kanban columns
│   │   ├── Tag.swift                  # Tags/Contexts
│   │   ├── Note.swift                 # Markdown notes
│   │   ├── Habit.swift                # Recurring habits
│   │   └── ActivityLog.swift          # App usage
│   └── Services/
│       ├── ActivityTracker.swift      # NSWorkspace observer
│       └── StreakCalculator.swift     # Habit streaks
├── Features/
│   ├── Goals/                         # Goal hierarchy views
│   ├── Tasks/                         # Task list, inbox, perspectives
│   ├── Kanban/                        # Board views
│   │   ├── Views/
│   │   │   ├── BoardView.swift        # Main kanban board
│   │   │   ├── BoardColumnView.swift  # Single column
│   │   │   ├── BoardCardView.swift    # Task card
│   │   │   └── BoardSettingsView.swift
│   │   └── ViewModels/
│   │       └── BoardViewModel.swift
│   ├── Notes/
│   │   └── Editor/
│   │       ├── MarkdownEditorView.swift
│   │       └── VimEngine/             # Vim mode implementation
│   ├── Calendar/                      # Calendar views
│   ├── Habits/                        # Habit tracking
│   └── Activity/                      # Productivity dashboard
├── Shared/
│   ├── Components/
│   │   ├── CommandPalette/            # Cmd+K interface
│   │   └── QuickCapture/              # Menu bar quick add
│   └── Navigation/
│       ├── MainNavigationView.swift   # 3-column layout
│       └── SidebarView.swift
└── MenuBar/
    └── MenuBarController.swift        # Status bar item
```

---

## Data Model (SQLite Schema)

### Goals (Yearly/Quarterly)
```sql
CREATE TABLE goals (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    goal_type TEXT NOT NULL, -- 'yearly' | 'quarterly'
    year INTEGER NOT NULL,
    quarter INTEGER,
    parent_goal_id TEXT REFERENCES goals(id),
    status TEXT DEFAULT 'active',
    progress REAL DEFAULT 0.0,
    created_at TEXT, updated_at TEXT
);
```

### Initiatives
```sql
CREATE TABLE initiatives (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    goal_id TEXT REFERENCES goals(id),
    status TEXT DEFAULT 'active',
    start_date DATE, target_date DATE,
    created_at TEXT, updated_at TEXT
);
```

### Projects
```sql
CREATE TABLE projects (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    initiative_id TEXT REFERENCES initiatives(id),
    status TEXT DEFAULT 'active',
    color TEXT, icon TEXT,
    created_at TEXT, updated_at TEXT
);
```

### Tasks (GTD)
```sql
CREATE TABLE tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    notes TEXT,
    project_id TEXT REFERENCES projects(id),
    board_column_id TEXT REFERENCES board_columns(id),
    parent_task_id TEXT REFERENCES tasks(id),
    status TEXT DEFAULT 'inbox', -- inbox|next|waiting|scheduled|someday|completed
    priority TEXT DEFAULT 'none',
    defer_date DATE, due_date DATE,
    is_flagged INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    recurrence_rule TEXT,
    created_at TEXT, updated_at TEXT, completed_at TEXT
);
```

### Kanban Boards
```sql
CREATE TABLE boards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    project_id TEXT REFERENCES projects(id),
    is_default INTEGER DEFAULT 0,
    created_at TEXT, updated_at TEXT
);

CREATE TABLE board_columns (
    id TEXT PRIMARY KEY,
    board_id TEXT NOT NULL REFERENCES boards(id),
    title TEXT NOT NULL,
    color TEXT,
    sort_order INTEGER DEFAULT 0,
    wip_limit INTEGER,
    maps_to_status TEXT,
    created_at TEXT
);
```

### Tags
```sql
CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    color TEXT,
    tag_type TEXT DEFAULT 'tag' -- 'tag' | 'context' | 'area'
);

CREATE TABLE task_tags (
    task_id TEXT REFERENCES tasks(id),
    tag_id TEXT REFERENCES tags(id),
    PRIMARY KEY (task_id, tag_id)
);
```

### Notes (Obsidian-like)
```sql
CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT DEFAULT '',
    linked_project_id TEXT,
    linked_task_id TEXT,
    is_daily_note INTEGER DEFAULT 0,
    daily_date DATE UNIQUE,
    created_at TEXT, updated_at TEXT
);

CREATE TABLE note_links (
    source_note_id TEXT REFERENCES notes(id),
    target_note_id TEXT REFERENCES notes(id),
    link_text TEXT
);

-- Full-text search
CREATE VIRTUAL TABLE notes_fts USING fts5(title, content);
```

### Habits
```sql
CREATE TABLE habits (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    frequency_type TEXT, -- daily|weekly|custom
    frequency_days TEXT,
    goal_id TEXT REFERENCES goals(id),
    color TEXT, icon TEXT,
    created_at TEXT
);

CREATE TABLE habit_completions (
    habit_id TEXT REFERENCES habits(id),
    completed_date DATE,
    PRIMARY KEY (habit_id, completed_date)
);
```

### Activity Tracking
```sql
CREATE TABLE tracked_apps (
    id TEXT PRIMARY KEY,
    bundle_identifier TEXT UNIQUE,
    app_name TEXT,
    category TEXT DEFAULT 'neutral' -- productive|neutral|distracting
);

CREATE TABLE activity_logs (
    id TEXT PRIMARY KEY,
    tracked_app_id TEXT REFERENCES tracked_apps(id),
    window_title TEXT,
    start_time TEXT, end_time TEXT,
    duration_seconds INTEGER,
    date DATE
);
```

---

## Dependencies (Swift Packages)

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
]
```

---

## UI Navigation Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Toolbar: [+ Quick Add] [Search Field          ] [Command Palette (⌘K)]    │
├─────────┬──────────────────────┬────────────────────────────────────────────┤
│ SIDEBAR │    CONTENT LIST      │           DETAIL / EDITOR                  │
│  200px  │       300px          │              Flexible                      │
├─────────┼──────────────────────┼────────────────────────────────────────────┤
│ INBOX   │  ☐ Task Title 1      │  Task: Buy groceries                      │
│ TODAY   │  ☐ Task Title 2      │  Project: Personal                        │
│ UPCOMING│  ☑ Task Title 3      │  Due: Tomorrow                            │
│ FLAGGED │  ☐ Task Title 4      │  Tags: @errands @weekend                  │
│─────────│                      │                                            │
│PROJECTS │                      │  Notes: [Markdown editor with vim]        │
│  Work   │                      │                                            │
│  Personal                      │  Subtasks:                                 │
│─────────│                      │  ☐ Check pantry                           │
│ GOALS   │                      │  ☐ Make list                              │
│  2025   │                      │                                            │
│─────────│                      │                                            │
│ NOTES   │                      │                                            │
│ HABITS  │                      │  [Complete] [Delete]                       │
│ ACTIVITY│                      │                                            │
└─────────┴──────────────────────┴────────────────────────────────────────────┘
```

---

## Key Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New task |
| `Cmd+Shift+N` | New note |
| `Cmd+K` | Command palette |
| `Cmd+1-9` | Switch perspectives |
| `Cmd+Enter` | Complete task |
| `Cmd+B` | Toggle board view |
| Global hotkey | Quick capture |

---

## Vim Mode Key Bindings

| Mode | Key | Action |
|------|-----|--------|
| Normal | `h/j/k/l` | Move cursor left/down/up/right |
| Normal | `w/b/e` | Word forward/backward/end |
| Normal | `0/$` | Line start/end |
| Normal | `gg/G` | File start/end |
| Normal | `i/a` | Insert at cursor/after |
| Normal | `I/A` | Insert at line start/end |
| Normal | `o/O` | New line below/above |
| Normal | `d{motion}` | Delete |
| Normal | `dd` | Delete line |
| Normal | `y{motion}` | Yank (copy) |
| Normal | `yy` | Yank line |
| Normal | `c{motion}` | Change |
| Normal | `p/P` | Paste after/before |
| Normal | `x` | Delete character |
| Normal | `u` | Undo |
| Normal | `Ctrl+r` | Redo |
| Normal | `v/V` | Visual char/line mode |
| Normal | `:` | Command mode |
| Insert | `Esc` | Return to Normal |
| Visual | `d/y/c` | Delete/yank/change selection |
