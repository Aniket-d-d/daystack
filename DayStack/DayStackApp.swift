import SwiftUI
import AppKit

@main
struct DayStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - Custom Panel (allows keyboard input in text fields)

class DayPanel: NSPanel {
    // Borderless NSPanel blocks keyboard by default — this unlocks it
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Window Position/Size Persistence

struct WindowPrefs: Codable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    var panel: DayPanel?
    let store = TaskStore()

    // Saved position/size stored next to DayStack.app — stays inside daystack folder
    var prefsURL: URL {
        Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent(".daystack-window.json")
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // No Dock icon, no Cmd+Tab
        buildPanel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Build Panel

    private func buildPanel() {
        let prefs   = loadPrefs()
        let initW   = CGFloat(prefs?.w ?? 290)
        let initH   = CGFloat(prefs?.h ?? 480)

        let root    = ContentView().environmentObject(store)
        let hosting = NSHostingView(rootView: root)

        let p = DayPanel(
            contentRect: NSRect(x: 0, y: 0, width: initW, height: initH),
            styleMask:   [.borderless, .resizable],   // resizable edges enabled
            backing:     .buffered,
            defer:       false
        )

        // ── Level: normal — widget sits behind other app windows (not always on top)
        p.level            = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        p.collectionBehavior = [.canJoinAllSpaces, .stationary]  // visible on every Space

        // ── Appearance
        p.isOpaque         = false
        p.hidesOnDeactivate = false  // stay visible when switching apps
        p.backgroundColor  = .clear
        p.hasShadow        = false

        // ── Draggable anywhere on the widget body
        p.isMovable                  = true
        p.isMovableByWindowBackground = true

        // ── Size constraints
        p.minSize = NSSize(width: 220, height: 300)
        p.maxSize = NSSize(width: 600, height: 900)

        p.contentView = hosting

        // ── Restore saved position, or default to top-right corner
        if let prefs = prefs {
            p.setFrameOrigin(NSPoint(x: prefs.x, y: prefs.y))
        } else {
            defaultPosition(p)
        }

        // ── Persist position and size whenever the user moves or resizes
        NotificationCenter.default.addObserver(
            self, selector: #selector(persistFrame),
            name: NSWindow.didMoveNotification,   object: p
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(persistFrame),
            name: NSWindow.didResizeNotification, object: p
        )

        p.orderFront(nil)
        panel = p
    }

    // ── Default position: top-right corner with 16 pt margin
    private func defaultPosition(_ p: DayPanel) {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        p.setFrameOrigin(NSPoint(
            x: f.maxX - p.frame.width  - 16,
            y: f.maxY - p.frame.height - 16
        ))
    }

    // MARK: - Prefs (position + size saved in daystack folder)

    @objc private func persistFrame() {
        guard let f = panel?.frame else { return }
        let prefs = WindowPrefs(x: f.origin.x, y: f.origin.y,
                                w: f.width,    h: f.height)
        if let data = try? JSONEncoder().encode(prefs) {
            try? data.write(to: prefsURL)
        }
    }

    private func loadPrefs() -> WindowPrefs? {
        guard let data = try? Data(contentsOf: prefsURL) else { return nil }
        return try? JSONDecoder().decode(WindowPrefs.self, from: data)
    }

}
