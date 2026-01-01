# Forge

> *Craft your productivity system*

A comprehensive macOS productivity app combining goal planning, GTD task management, Kanban boards, note-taking with Vim mode, and activity tracking.

## Features

- **Goal Hierarchy**: Yearly → Quarterly → Initiatives → Projects → Tasks
- **GTD Task Management**: Inbox, contexts, defer dates, smart perspectives
- **Kanban Boards**: Visual task management with drag-and-drop
- **Calendar & Habits**: Scheduling, recurring tasks, streak tracking
- **Note-Taking**: Markdown editor with Vim mode and `[[wiki-links]]`
- **Activity Tracking**: RescueTime-like app usage monitoring

## Tech Stack

- **SwiftUI** - Native macOS UI
- **SQLite** via GRDB.swift - Local database
- **Custom Vim Engine** - Full vim keybindings in the editor

## Documentation

- [Implementation Plan](docs/PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)

## Requirements

- macOS 14.0+
- Xcode 15.0+

## Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd Forge

# Open in Xcode
open Forge.xcodeproj
```

## License

MIT
