// TestInputs.swift
// Builds fixed BarInputs for the layout and snapshot tests: a set time, levels and real app icons.
// Exists so every test lays out the same bar state and differs only in what it is checking.
// Defines: TestInputs
// Notes: docs/notes/app/Tests/OpenTaskbarTests/TestInputs.swift.md
import AppKit
import ApplicationServices
@testable import OpenTaskbar

@MainActor
enum TestInputs {
    // Saturday, September 26, 2026 at 21:24 local time, the time on the Windows screenshots.
    static var screenshotTime: Date {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 9; parts.day = 26; parts.hour = 21; parts.minute = 24
        return Calendar.current.date(from: parts) ?? Date()
    }

    // App bundles from the standard folders, sorted, so every run draws the same icons.
    static func appPaths(_ count: Int) -> [String] {
        var paths: [String] = []
        for folder in ["/Applications", "/System/Applications", "/System/Applications/Utilities"] {
            let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []).filter { $0.hasSuffix(".app") }.sorted()
            paths += names.map { "\(folder)/\($0)" }
        }
        return Array(paths.prefix(count))
    }

    // Every third launcher has a window and the second one is frontmost, like the screenshots.
    static func launchers(_ count: Int) -> [LauncherEntry] {
        appPaths(count).enumerated().map { index, path in
            let launcher = Launcher(path: path, title: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
                                    icon: NSWorkspace.shared.icon(forFile: path))
            return LauncherEntry(launcher: launcher, pinned: true, hasWindows: index % 3 == 1, active: index == 1)
        }
    }

    static func settings(rows: Int = 1, large: Bool = false) -> BarSettings {
        var settings = BarSettings()
        settings.rows = rows
        settings.iconSize = large ? 24 : 16
        settings.barHeight = large ? 40 : 30
        settings.whiteStatusMarks = false
        settings.show["search"] = false
        settings.show["tools"] = false
        settings.show["displayBrightness"] = false
        settings.show["keyboardBrightness"] = false
        settings.show["microphone"] = false
        settings.show["displayOff"] = false
        settings.show["calculator"] = false
        settings.dateFormat = "%-m/%-d/%Y"
        settings.transparencyOn = false
        settings.brightness = 0
        return settings.clamped()
    }

    static func inputs(_ settings: BarSettings, launchers count: Int, width: CGFloat = 1280, page: Int = 0) -> BarInputs {
        let tile = StatusItemTile(app: "Claude", pid: 1, ref: AXRef(element: AXUIElementCreateApplication(1)),
                                  icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Utilities/Terminal.app"),
                                  glyph: nil, letter: "C", x: 0)
        return BarInputs(
            settings: settings, palette: BarPalette(settings), metrics: TaskbarMetrics(settings), width: width,
            startIcon: nil, launchers: launchers(count), menuTitles: [],
            volume: AudioLevel(device: 0, name: "Speakers", level: 23, muted: false),
            microphone: AudioLevel(device: 0, name: "Microphone", level: 50, muted: false),
            battery: BatteryState(present: true, percent: 88, charging: false, onAdapter: true, minutesRemaining: -2,
                                  condition: "Good", cycles: 100),
            wifi: WiFiState(powered: true, connected: true, ssid: "Home", rssi: -50, channel: 36, address: nil),
            wifiBars: 3, statusItems: [tile], hour24: true, now: screenshotTime, page: page)
    }
}
