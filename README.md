<div align="center">

# DayStack

**A minimal, native daily task widget for macOS**

![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square&logo=apple)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Offline](https://img.shields.io/badge/Internet-None-red?style=flat-square)

</div>

---

DayStack is a lightweight task widget that lives on your Mac desktop — behind all your app windows, always there when you need it. No Electron. No Chrome. No npm. Just pure native Swift talking directly to macOS.

---

## Preview

```
┌──────────────────────────────────────┐
│  Month  Mo Tu We Th Fr Sa Su   All   │
│  ────────────────────────────────── │
│  THU · 02 APR 2026                   │
│                                      │
│  ○  Design the homepage              │
│  ○  Call with Raj @ 3pm              │
│  ✓  Review pull request #42          │
│  ↩  YCombinator form       carry forwarded  │
│                                      │
│  ┌ ─ ─ + Add Task ─ ─ ─ ─ ┐  ↩     │
└──────────────────────────────────────┘
```

---

## Features

### Daily View
- **Week strip** — 7 days centred on today, click any day to switch
- **Month calendar** — opens inline with red dots on days that have incomplete tasks. Click any date to jump to it.
- **All Tasks view** — every task ever recorded, filterable by All / Incomplete / Completed
- **Inline editing** — click any task title to rename it, on any date including past days
- **Notes** — click `›` on any task to expand a free-form notes area. Auto-saves.
- **Drag to reorder** — drag handle appears on hover to rearrange tasks within the day
- **Hover to delete** — `✕` appears on hover
- **Past days** — fully viewable. Check/uncheck tasks and edit titles and notes on any past date.

### Carry Forward
- **`↩` button** next to Add Task — opens a sheet of all incomplete tasks from previous days, grouped by date
- Click **`+ Add`** on any task to copy it to today. The original stays on its date, dimmed, marked as carry forwarded.
- Carry forwarded tasks show as a dim amber marker on their original date — not counted as incomplete, not shown in the Incomplete filter, and not triggering the red dot on the calendar.
- **Linked renaming** — rename a task on any date and the update propagates to every copy of that task across all carry-forward dates automatically.
- **Smart deletion** — deleting a carried task only removes it from that date forward. The previous copy is automatically restored as a live incomplete task.
- **Full history log** — expand any carried task to see every date it passed through:

```
── History
◎ Created    Mon 31 Mar
↩ Carried    Wed 02 Apr
↩ Carried    Fri 04 Apr
✓ Completed  Fri 04 Apr
```

### All Tasks View
- Groups all tasks by date, newest first
- Filter by **All / Incomplete / Completed**
- Footprint rows (carry forwarded markers) shown in amber — click any footprint to jump to the date where the task currently lives
- Expand any task to see its notes and carry-forward history

### Window
- Sits on the **desktop layer** — behind all app windows, always visible on the desktop
- **Draggable** anywhere on screen — click and drag the widget body
- **Resizable** — drag any edge or corner. Minimum 220×300, maximum 600×900.
- **Remembers position and size** across restarts
- **Auto-launches on login** — starts with your Mac automatically after first build
- **Right-click** anywhere on the widget → Quit DayStack

---

## What it is built with

| Technology | Purpose | Maintained by |
|---|---|---|
| Swift + SwiftUI | UI and app logic | Apple |
| SQLite3 | Local database | Apple (built into macOS) |
| AppKit (NSPanel) | Floating window | Apple |

No external libraries. No internet connection. No telemetry.
Security patches come automatically with macOS — you do nothing.

---

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools — install with one Terminal command

---

## Installation

**Step 1 — Install the Swift compiler** *(one time only)*

```bash
xcode-select --install
```

A popup appears — click Install. Takes a few minutes.

**Step 2 — Clone and build**

```bash
git clone https://github.com/Aniket-d-d/daystack.git
cd daystack
./build.sh
```

The script compiles everything, produces `DayStack.app`, and registers it as a login item so it starts automatically on every restart.

**Step 3 — Open it**

Right-click `DayStack.app` → **Open** → **Open**
*(macOS asks once because the app is not from the App Store — after that it opens normally)*

---

## Data storage

Everything stays in the project folder — nothing is written elsewhere on your Mac.

```
daystack/
├── DayStack.app           ← the compiled app
├── daystack.db            ← your tasks (created on first run)
├── .daystack-window.json  ← saved window position and size
├── build.sh               ← build script
└── DayStack/              ← Swift source files
```

To **back up** your tasks: copy `daystack.db`
To **uninstall** completely: delete the `daystack` folder

---

## Project structure

```
DayStack/
├── DayStackApp.swift    — app entry point, window setup, login item
├── Models.swift         — Task model, date utilities, colour palette
├── TaskStore.swift      — all SQLite database operations
├── ContentView.swift    — main widget shell, navigation, week strip
├── TasksView.swift      — daily task list, inline editing, add task, carry forward
├── CalendarView.swift   — month calendar with incomplete task dots
└── AllTasksView.swift   — all tasks view with filters and footprint navigation
```

---

## Contributing

Pull requests are welcome. If you find a bug or have a feature idea, open an issue.

If DayStack is useful to you, consider sponsoring — it helps keep the project alive.

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?style=flat-square)](https://github.com/sponsors/Aniket-d-d)

---

## License

MIT © 2026 Aniket-d-d

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.