# Forge - Implementation Plan

> *Craft your productivity system*

## Overview

A comprehensive macOS productivity app combining:
- **Goal Planning**: Yearly → Quarterly → Initiatives → Projects → Tasks
- **GTD Task Management**: Inbox, contexts, defer dates, perspectives
- **Kanban Boards**: Visual task management with drag-and-drop
- **Calendar & Habits**: Scheduling, recurring tasks, habit tracking with streaks
- **Note-Taking**: Markdown editor with Vim mode and wiki-style [[links]]
- **Activity Tracking**: RescueTime-like app usage monitoring

## Tech Stack

| Component | Technology |
|-----------|------------|
| UI Framework | SwiftUI |
| Database | SQLite via GRDB.swift |
| Markdown | swift-markdown + swift-markdown-ui |
| Text Editor | Custom NSTextView with Vim engine |
| Global Hotkeys | KeyboardShortcuts package |
| Architecture | MVVM + Repository pattern |

---

## Implementation Phases

### Phase 1: Foundation (Core Infrastructure)
1. Create Xcode project (macOS App, SwiftUI)
2. Configure entitlements (App Sandbox, Accessibility)
3. Add SPM dependencies
4. Implement `AppDatabase` with GRDB and migrations
5. Create all model structs with GRDB conformance
6. Build base repositories (Task, Project, Tag)
7. Set up 3-column NavigationSplitView structure
8. Implement basic sidebar navigation

### Phase 2: Task Management & Kanban
1. Build `TaskListView` and `TaskRowView`
2. Implement `InboxView` with quick capture
3. Create `TaskDetailView` with editing
4. Build perspectives: Today, Upcoming, Flagged
5. **Kanban Board Implementation:**
   - `BoardView` with horizontal scroll columns
   - `BoardColumnView` with vertical task cards
   - `BoardCardView` with title, due date, tags
   - Drag-and-drop between columns (SwiftUI `.draggable`/`.dropDestination`)
   - Column customization (add/remove/rename)
   - WIP limits (optional)
6. Sync board columns with task status

### Phase 3: Goals & Projects
1. Implement Goal model and repository
2. Build `GoalListView` with year/quarter grouping
3. Create `GoalDetailView` with progress tracking
4. Build Initiative views
5. Link projects → initiatives → goals
6. Progress rollup calculations
7. Timeline/roadmap visualization

### Phase 4: Note-Taking with Vim Mode
1. Create Note model and repository
2. Build `NoteListView` with search
3. Implement `MarkdownEditorView` (NSTextView wrapper)
4. Add Markdown syntax highlighting
5. **Vim Mode Engine:**
   - `VimState` state machine (Normal/Insert/Visual/Command)
   - `VimMotions` (h,j,k,l,w,b,e,0,$,gg,G)
   - `VimOperators` (d,y,c,p,x)
   - `VimTextObjects` (iw,aw,ip,i",etc.)
   - Mode indicator UI
6. Implement `[[wiki-link]]` parsing
7. Build backlinks view
8. Daily notes with auto-creation
9. Full-text search with FTS5

### Phase 5: Calendar & Habits
1. Build `CalendarView` (month/week/day)
2. Display tasks by due date
3. Drag-to-schedule functionality
4. Implement Habit model
5. Build `HabitListView` with today's habits
6. Streak calculation and visualization
7. Recurring task creation

### Phase 6: Activity Tracking
1. Request Accessibility permissions
2. Implement `ActivityTracker` (NSWorkspace notifications)
3. Track active app via `NSWorkspace.shared.frontmostApplication`
4. Window title tracking via Accessibility API
5. Build `ActivityDashboardView`
6. Productivity score calculation
7. Daily/weekly reports

### Phase 7: Polish & Power Features
1. Command palette (Cmd+K)
2. Menu bar quick capture
3. Global hotkey for quick entry
4. Keyboard navigation throughout
5. Weekly review system
6. Data export
7. Settings/preferences
8. Performance optimization
