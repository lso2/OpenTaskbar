// CloseQuitsApp.swift
// Quits an app when its last standard window closes, the way closing the last window does on Windows.
// Exists as the port of the window filter in init.lua, sending the same quit request Command+Q sends.
// Defines: CloseQuitsApp
// Notes: docs/notes/app/Sources/OpenTaskbar/WindowBehavior/CloseQuitsApp.swift.md
import AppKit
import ApplicationServices

@MainActor
final class CloseQuitsApp {
    static let shared = CloseQuitsApp()

    static let neverQuit: Set<String> = [
        "com.apple.finder", "org.hammerspoon.Hammerspoon", "org.pqrs.Karabiner-Elements.Settings",
        "com.ethanbills.DockDoor", "com.plexpixel.OpenTaskbar",
    ]
    static let neverQuitNames: Set<String> = ["Finder", "Hammerspoon", "Karabiner-Elements", "DockDoor", "OpenTaskbar"]

    private(set) var running = false
    private var listening = false
    // Only an app seen holding a window can have closed its last one.
    private var hadWindows: Set<pid_t> = []

    func start() {
        running = true
        guard !listening else { return }
        listening = true
        WindowList.shared.observe { pid in
            if WindowList.shared.count(for: pid) > 0 { CloseQuitsApp.shared.hadWindows.insert(pid) }
        }
        WindowObserver.shared.listen { pid, notification in
            guard notification == kAXUIElementDestroyedNotification else { return }
            CloseQuitsApp.shared.windowClosed(pid)
        }
    }

    func stop() { running = false }

    // A short wait lets an app that replaces one window with another keep running.
    private func windowClosed(_ pid: pid_t) {
        guard running, hadWindows.contains(pid) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            MainActor.assumeIsolated { CloseQuitsApp.shared.check(pid) }
        }
    }

    private func check(_ pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated,
              app.activationPolicy == .regular,
              !CloseQuitsApp.neverQuit.contains(app.bundleIdentifier ?? ""),
              !CloseQuitsApp.neverQuitNames.contains(app.localizedName ?? "") else { return }
        Task {
            // Minimized and hidden windows still count, so neither ever quits an app.
            let remaining = await Task { @AXActor in WindowList.read(pid).count }.value
            guard remaining == 0, CloseQuitsApp.shared.running else { return }
            CloseQuitsApp.shared.hadWindows.remove(pid)
            Log.windows.info("last window closed, quitting \(app.localizedName ?? "app", privacy: .public)")
            app.terminate()
        }
    }
}
