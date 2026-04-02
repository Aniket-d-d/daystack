#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# DayStack build script
# Run this once to produce DayStack.app in the same folder.
# Requires: Xcode Command Line Tools (xcode-select --install)
# ─────────────────────────────────────────────────────────────────────────────

set -e  # stop immediately on any error

APP="DayStack.app"
BINARY_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"

# Full absolute path to DayStack.app (used for login item)
APP_FULL_PATH="$(cd "$(dirname "$0")" && pwd)/$APP"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/com.daystack.app.plist"

# ── 1. Clean previous build ───────────────────────────────────────────────────
echo "→ Cleaning previous build..."
rm -rf "$APP"
mkdir -p "$BINARY_DIR" "$RESOURCES_DIR"

# ── 2. Detect Mac architecture ────────────────────────────────────────────────
ARCH=$(uname -m)   # arm64 = Apple Silicon, x86_64 = Intel
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macos13.0"
else
    TARGET="x86_64-apple-macos13.0"
fi
echo "→ Detected architecture: $ARCH"

# ── 3. Locate the macOS SDK ───────────────────────────────────────────────────
SDK=$(xcrun --show-sdk-path --sdk macosx)
echo "→ Using SDK: $SDK"

# ── 4. Compile all Swift source files ────────────────────────────────────────
echo "→ Compiling (this takes ~30–60 seconds)..."

swiftc \
    -sdk          "$SDK"    \
    -target       "$TARGET" \
    -parse-as-library       \
    -O                      \
    -framework SwiftUI      \
    -framework AppKit       \
    -framework Foundation   \
    -lsqlite3               \
    DayStack/Models.swift       \
    DayStack/TaskStore.swift    \
    DayStack/DayStackApp.swift  \
    DayStack/ContentView.swift  \
    DayStack/TasksView.swift    \
    DayStack/CalendarView.swift \
    DayStack/AllTasksView.swift \
    -o "$BINARY_DIR/DayStack"

# ── 5. Write Info.plist ───────────────────────────────────────────────────────
echo "→ Writing Info.plist..."
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>DayStack</string>
    <key>CFBundleDisplayName</key>
    <string>DayStack</string>
    <key>CFBundleIdentifier</key>
    <string>com.daystack.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>DayStack</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

# ── 6. Register as login item (auto-launch on Mac startup) ────────────────────
echo "→ Registering login item..."

mkdir -p "$LAUNCH_AGENT_DIR"

# Unload existing entry silently if present
launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true

# Write the LaunchAgent plist — tells macOS to open DayStack on every login
cat > "$LAUNCH_AGENT_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.daystack.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/open</string>
        <string>$APP_FULL_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

# Load the agent so macOS knows about it
launchctl load "$LAUNCH_AGENT_PLIST"

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "✓ Build complete → $APP"
echo "✓ Login item registered — DayStack will launch automatically on every restart"
echo ""
echo "To open DayStack for the first time:"
echo "  Right-click DayStack.app → Open → click Open"
echo "  (macOS will ask once — after that it opens automatically on login)"
echo ""
echo "⚠ Important: do not move the daystack-swift folder after building."
echo "  If you move it, run ./build.sh again from the new location to update the login item."
echo ""