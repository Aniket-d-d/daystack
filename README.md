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
┌─────────────────────────────────┐
│  Month  Mo Tu We Th Fr Sa  All  │
│  ────────────────────────────── │
│  THU · 02 APR 2026              │
│                                 │
│  ○  Design the homepage         │
│  ○  Call with Raj @ 3pm         │
│  ✓  Review pull request #42     │
│                                 │
│  ┌ ─ ─ + Add Task ─ ─ ─ ─ ─ ┐  │
└─────────────────────────────────┘
```

---

## Features

- **Week strip** — 7 days centred on today, click any day to switch
- **Month calendar** — opens inline with red dots on days with incomplete tasks
- **All Tasks view** — every task ever, filterable by All / Incomplete / Completed
- **Inline editing** — click any task title to rename it
- **Notes** — expand any task to add free-form notes or subtasks
- **Drag to reorder** — drag handle on hover to rearrange tasks
- **Hover to delete** — `✕` appears on hover
- **Past days** — view history, check/uncheck old tasks, read notes
- **Draggable & resizable** — position and size it however you like
- **Remembers position** — widget stays where you put it across restarts
- **Auto-launches on login** — starts with your Mac automatically
- **Hides behind apps** — sits on the desktop layer, never in the way

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
git clone https://github.com/YOUR_USERNAME/daystack.git
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
├── TasksView.swift      — daily task list, inline editing, add task
├── CalendarView.swift   — month calendar with incomplete task dots
└── AllTasksView.swift   — all tasks view with filter toggles
```

---

## Contributing

Pull requests are welcome. If you find a bug or have a feature idea, open an issue.

If DayStack is useful to you, consider sponsoring — it helps keep the project alive.

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?style=flat-square)](https://github.com/sponsors/Aniket-d-d)

---

## License

MIT © 2026 [Aniket-d-d]

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.