// BarItemMenus.swift
// The right click menu of each bar item: its own actions, its System Settings page, Hide and Remove.
// Exists so every item answers a right click with its own menu, leaving the OpenTaskbar menu to Start, empty bar and the chevron.
// Defines: BarItemMenus
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/BarItemMenus.swift.md
import AppKit
import PrivateAPI

@MainActor
enum BarItemMenus {
    static func settings(_ pane: String) -> @MainActor () -> Void {
        TrayMenus.openPane("x-apple.systempreferences:\(pane)")
    }

    // Takes the item off the bar; its switch in Settings, Items tab, brings it back.
    static func remove(_ item: String) -> MenuEntry {
        MenuEntry("Remove from taskbar") { SettingsStore.shared.update { $0.show[item] = false } }
    }

    // Moves a tray item behind the chevron.
    static func hide(_ id: String) -> MenuEntry {
        MenuEntry("Hide") { SettingsStore.shared.update { $0 = TrayOrder.hidden($0, id: id, true) } }
    }

    static func levels(_ current: Double?, _ values: [Double], set: @escaping @MainActor (Double) -> Void) -> [MenuEntry] {
        values.map { value in
            MenuEntry("\(Int(value))%", checked: current.map { abs($0 - value) < 6 } ?? false) { set(value) }
        }
    }

    // Moves a tray item from the flyout back onto the bar.
    static func show(_ id: String) -> MenuEntry {
        MenuEntry("Show on taskbar") { SettingsStore.shared.update { $0 = TrayOrder.hidden($0, id: id, false) } }
    }

    // Nil for the kinds whose right click is not a list of entries: Start, the chevron, app menus and
    // launchers. Hidden is true for an item in the chevron flyout, which offers Show in place of Hide.
    static func entries(for kind: BarZoneKind, anchor: NSRect, in view: BarView, hidden: Bool = false) -> [MenuEntry]? {
        let tray = kind.trayID.map { [MenuEntry.separator, hidden ? show($0) : hide($0)] } ?? []
        switch kind {
        case .search:
            return [MenuEntry("Open Search") { StartPanel.shared.openSearch(from: view) },
                    MenuEntry("Open Spotlight") { SpotlightLauncher.open() }, .separator, remove("search")]
        case .taskView:
            return [MenuEntry("Mission Control") { CoreDockSendNotification("com.apple.expose.awake" as CFString, 0) },
                    MenuEntry("App Exposé") { CoreDockSendNotification("com.apple.expose.front.awake" as CFString, 0) },
                    .separator, remove("taskView")]
        case .displayOff:
            return [MenuEntry("Turn Display Off") { PowerActions.perform(.displaySleep) }, .separator, remove("displayOff")]
        case .files:
            let home = FileManager.default.homeDirectoryForCurrentUser
            return [("Home", home), ("Documents", home.appendingPathComponent("Documents")),
                    ("Downloads", home.appendingPathComponent("Downloads")),
                    ("Applications", URL(fileURLWithPath: "/Applications"))].map { title, url in
                MenuEntry(title) { NSWorkspace.shared.open(url) }
            }
        case .calculator:
            return [MenuEntry("Open Calculator") { BarClickActions.openApp("com.apple.calculator") }, .separator,
                    remove("calculator")]
        case .pageUp, .pageDown:
            return [MenuEntry("Previous Page") { BarClickActions.turnPage(-1) },
                    MenuEntry("Next Page") { BarClickActions.turnPage(1) }]
        case .statusItem(let app):
            guard let tile = StatusItemMirror.shared.tile(app) else { return nil }
            return [.header(app), .separator, MenuEntry("Open") { StatusItemMirror.shared.press(tile) }] + tray
        case .tools:
            return [MenuEntry("Open Tools") { ToolsPanel.shared.toggle(above: anchor, bar: view) }] + tray + [remove("tools")]
        case .display:
            return levels(DisplayBrightness.level, [25, 50, 75, 100]) { DisplayBrightness.set($0) }
                + [.separator, MenuEntry("Displays Settings", action: settings("com.apple.Displays-Settings.extension"))]
                + tray + [remove("displayBrightness")]
        case .keyboard:
            return levels(KeyboardBacklight.shared.level, [0, 25, 50, 75, 100]) { KeyboardBacklight.shared.set($0) }
                + [.separator, MenuEntry("Keyboard Settings", action: settings("com.apple.Keyboard-Settings.extension"))]
                + tray + [remove("keyboardBrightness")]
        case .microphone:
            return microphone() + tray + [remove("microphone")]
        case .volume:
            return TrayMenus.volume() + tray + [remove("volume")]
        case .battery:
            let showing = SettingsStore.shared.current.shows("batteryText")
            return [MenuEntry("Show Percentage", checked: showing) { SettingsStore.shared.update { $0.show["batteryText"] = !showing } },
                    MenuEntry("Battery Settings", action: settings("com.apple.Battery-Settings.extension"))]
                + tray + [remove("battery")]
        case .wifi:
            let powered = WiFi.shared.state.powered
            return [MenuEntry(powered ? "Turn Wi-Fi Off" : "Turn Wi-Fi On") { WiFi.shared.setPower(!powered) },
                    MenuEntry("Wi-Fi Settings", action: settings("com.apple.wifi-settings-extension"))]
                + tray + [remove("wifi")]
        case .spotlight:
            return [MenuEntry("Open Spotlight") { SpotlightLauncher.open() },
                    MenuEntry("Spotlight Settings", action: settings("com.apple.Spotlight-Settings.extension"))]
                + tray + [remove("spotlight")]
        case .controlCenter:
            return [MenuEntry("Open Control Center") { ControlCenterReader.shared.press("controlcenter") },
                    MenuEntry("Control Center Settings", action: settings("com.apple.ControlCenter-Settings.extension"))]
                + tray + [remove("controlCenter")]
        case .clock:
            return clock(anchor: anchor, in: view)
        case .notifications:
            return [MenuEntry("Open Notification Center") { ControlCenterReader.shared.press("clock") },
                    MenuEntry("Notifications Settings", action: settings("com.apple.Notifications-Settings.extension")),
                    .separator, remove("notifications")]
        case .showDesktop:
            return [MenuEntry("Show Desktop") { CoreDockSendNotification("com.apple.showdesktop.awake" as CFString, 0) },
                    .separator, remove("showDesktop")]
        case .start, .overflow, .menu, .launcher:
            return nil
        }
    }

    private static func microphone() -> [MenuEntry] {
        let control = AudioControl.input
        control.refresh()
        guard let state = control.state else { return [.header("No input device")] }
        var items: [MenuEntry] = [.header(state.name), .separator,
                                  MenuEntry(state.muted ? "Unmute" : "Mute") { AudioControl.input.toggleMute() }, .separator]
        for device in CoreAudio.devices(input: true) {
            items.append(MenuEntry(device.name, checked: device.id == state.device) { AudioControl.input.setDefault(device.id) })
        }
        items += [.separator, MenuEntry("Sound Settings", action: settings("com.apple.Sound-Settings.extension"))]
        return items
    }

    private static func clock(anchor: NSRect, in view: BarView) -> [MenuEntry] {
        let current = SettingsStore.shared.current
        let hour24 = ClockPreference.hour24
        return [
            MenuEntry("Open Calendar") { CalendarPanel.shared.toggle(above: anchor, bar: view) },
            MenuEntry("Date & Time Settings", action: settings("com.apple.Date-Time-Settings.extension")),
            .separator,
            MenuEntry("24-Hour Time", checked: hour24) {
                ClockPreference.setHour24(!hour24)
                SettingsModel.shared.hour24 = !hour24
                BarController.shared.redraw()
            },
            MenuEntry("Show Date", checked: current.shows("date")) { SettingsStore.shared.update { $0.show["date"] = !current.shows("date") } },
            MenuEntry("Show Time", checked: current.shows("time")) { SettingsStore.shared.update { $0.show["time"] = !current.shows("time") } },
        ]
    }
}
