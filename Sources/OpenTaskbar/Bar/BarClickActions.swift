// BarClickActions.swift
// Performs what a left click on each part of the bar does.
// Exists so BarView only finds the zone under the pointer and this file decides the action.
// Defines: BarClickActions
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarClickActions.swift.md
import AppKit
import PrivateAPI

@MainActor
enum BarClickActions {
    static func perform(_ zone: BarZone, in view: BarView) {
        if case .launcher(let index) = zone.kind {
            launcherClicked(index, zone: zone, in: view)
            return
        }
        perform(zone.kind, anchor: view.screenRect(zone.rect), x: zone.rect.minX, in: view)
    }

    // Anchor is the item's rectangle on screen, x its left edge in the bar; the chevron flyout
    // passes its own cell for items it holds.
    static func perform(_ kind: BarZoneKind, anchor: NSRect, x: CGFloat, in view: BarView) {
        switch kind {
        case .start: StartPanel.shared.toggle(from: view)
        case .search: StartPanel.shared.openSearch(from: view)
        case .taskView: CoreDockSendNotification("com.apple.expose.awake" as CFString, 0)
        case .displayOff: PowerActions.perform(.displaySleep)
        case .files: NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        case .calculator: openApp("com.apple.calculator")
        case .menu(let index): AppMenuReader.shared.open(index, x: x, in: view)
        case .launcher: break
        case .pageUp: turnPage(-1)
        case .pageDown: turnPage(1)
        case .overflow: TrayOverflowPanel.shared.toggle(above: anchor, bar: view)
        case .statusItem(let app):
            if let tile = StatusItemMirror.shared.tile(app) { StatusItemMirror.shared.press(tile) }
        case .tools: ToolsPanel.shared.toggle(above: anchor, bar: view)
        case .display: SliderPanel.shared.toggle(.display, above: anchor, bar: view)
        case .keyboard: SliderPanel.shared.toggle(.keyboard, above: anchor, bar: view)
        case .microphone: SliderPanel.shared.toggle(.microphone, above: anchor, bar: view)
        case .volume: SliderPanel.shared.toggle(.volume, above: anchor, bar: view)
        case .battery: BatteryPanel.shared.toggle(above: anchor, bar: view)
        case .wifi: WiFiPanel.shared.toggle(above: anchor, bar: view)
        case .spotlight: SpotlightLauncher.open()
        case .controlCenter: ControlCenterReader.shared.press("controlcenter")
        case .clock: CalendarPanel.shared.toggle(above: anchor, bar: view)
        case .notifications: ControlCenterReader.shared.press("clock")
        case .showDesktop: CoreDockSendNotification("com.apple.showdesktop.awake" as CFString, 0)
        }
    }

    // Not running: launch it. Frontmost: minimize its window, as clicking the active button does
    // on Windows. Otherwise bring it forward, restoring a window when every one is minimized.
    static func launcherClicked(_ index: Int, zone: BarZone, in view: BarView) {
        let entries = BarController.shared.currentLaunchers
        guard entries.indices.contains(index) else { return }
        let entry = entries[index]
        let path = entry.launcher.path

        guard let app = PinnedStore.runningApp(for: path) else {
            LauncherHop.shared.start(path)
            PinnedStore.launch(path)
            return
        }

        let windows = WindowList.shared.windows(for: app.processIdentifier)
        if windows.isEmpty {
            LauncherHop.shared.start(path)
            PinnedStore.launch(path)
        } else if entry.active, windows.contains(where: { !$0.minimized }) {
            WindowActions.minimizeFocused(of: app.processIdentifier)
        } else if windows.allSatisfy(\.minimized), let first = windows.first {
            WindowActions.raise(first)
        } else {
            app.activate()
        }
    }

    static func turnPage(_ step: Int) {
        let controller = BarController.shared
        controller.page = min(max(0, controller.page + step), max(0, controller.pageCount - 1))
        controller.redraw()
    }

    static func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
