// PinnedStore.swift
// The pinned launcher list: reading, pinning, unpinning, reordering and launching.
// Exists so every gesture that changes the pinned list writes through one place.
// Defines: Launcher, PinnedStore
// Notes: docs/notes/app/Sources/OpenTaskbar/Launchers/PinnedStore.swift.md
import AppKit

struct Launcher: Equatable {
    let path: String
    let title: String
    let icon: NSImage
}

@MainActor
enum PinnedStore {
    private static var icons: [String: NSImage] = [:]

    static var paths: [String] { SettingsStore.shared.current.pinnedApps }

    static func title(for path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    static func icon(for path: String) -> NSImage {
        if let cached = icons[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        icons[path] = image
        return image
    }

    // Launchers whose bundle is missing from disk are skipped, the way the Lua build skipped them.
    static func launchers() -> [Launcher] {
        paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return Launcher(path: path, title: title(for: path), icon: icon(for: path))
        }
    }

    static func runningApp(for path: String) -> NSRunningApplication? {
        let wanted = URL(fileURLWithPath: path).standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL.path == wanted
        }
    }

    static func pin(_ path: String) {
        guard !path.isEmpty, !paths.contains(path) else { return }
        SettingsStore.shared.update { $0.pinnedApps.append(path) }
    }

    static func unpin(_ path: String) {
        SettingsStore.shared.update { $0.pinnedApps.removeAll { $0 == path } }
    }

    static func setOrder(_ ordered: [String]) {
        SettingsStore.shared.update { $0.pinnedApps = ordered }
    }

    // Opening a running app sends it a reopen event, which brings back a window when it has none.
    static func launch(_ path: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: configuration)
    }

    static func open(files: [URL], with path: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(files, withApplicationAt: URL(fileURLWithPath: path), configuration: configuration)
    }
}
