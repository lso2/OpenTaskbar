// StartContextMenu.swift
// The short administrative menu that right clicking the launcher or empty bar opens.
// Exists as the port of startContextMenu in bottombar-menus.lua.
// Defines: StartContextMenu
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/StartContextMenu.swift.md
import AppKit

@MainActor
enum StartContextMenu {
    static func open(_ path: String) -> @MainActor () -> Void {
        { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
    }

    static func entries() -> [MenuEntry] {
        [
            MenuEntry("OpenTaskbar Settings") { SettingsWindow.shared.show() },
            MenuEntry("Check for Updates") { Updater.shared.checkForUpdates() },
            .separator,
            MenuEntry("Activity Monitor", action: open("/System/Applications/Utilities/Activity Monitor.app")),
            MenuEntry("Terminal", action: open("/System/Applications/Utilities/Terminal.app")),
            MenuEntry("System Settings", action: open("/System/Applications/System Settings.app")),
            MenuEntry("Finder", action: open(FileManager.default.homeDirectoryForCurrentUser.path)),
            .separator,
            MenuEntry("Restart OpenTaskbar") { relaunch() },
            MenuEntry("Quit OpenTaskbar") { NSApp.terminate(nil) },
            .separator,
            MenuEntry("Lock Screen") { PowerActions.perform(.lock) },
            MenuEntry("Restart") { PowerActions.perform(.restart) },
            MenuEntry("Shut Down") { PowerActions.perform(.shutdown) },
        ]
    }

    // A detached shell waits for this process to exit, then opens the bundle again.
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        PowerActions.run("/bin/sh", ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"\(path)\""])
        NSApp.terminate(nil)
    }
}
