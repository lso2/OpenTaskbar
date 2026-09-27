// TrayOrder.swift
// The tray's item identifiers, their saved left to right order, and which of them sit behind the chevron.
// Exists so the bar, the chevron flyout, dragging and Settings all read one order and one hidden list.
// Defines: TrayOrder
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/TrayOrder.swift.md
import Foundation

enum TrayOrder {
    // Left to right, the order a fresh install shows. Mirrored status items come before these.
    static let systemIDs = [
        "tools", "displayBrightness", "keyboardBrightness", "microphone", "battery", "volume", "wifi",
        "spotlight", "controlCenter",
    ]

    static func statusID(_ app: String) -> String { "status:\(app)" }

    static func app(of id: String) -> String? {
        id.hasPrefix("status:") ? String(id.dropFirst("status:".count)) : nil
    }

    // Every item that exists right now: status items in menu bar order, then the switched-on system items.
    static func present(_ settings: BarSettings, apps: [String], batteryPresent: Bool) -> [String] {
        var ids = settings.shows("statusItems") ? apps.map(statusID) : []
        for id in systemIDs where settings.shows(id) && (id != "battery" || batteryPresent) {
            ids.append(id)
        }
        return ids
    }

    // The saved order for items it knows. A new item goes right after the item that precedes it
    // in the default order, or first when none does.
    static func arrange(_ present: [String], stored: [String]) -> [String] {
        let known = Set(present)
        var result: [String] = []
        for id in stored where known.contains(id) && !result.contains(id) { result.append(id) }
        for (index, id) in present.enumerated() where !result.contains(id) {
            var at = 0
            for previous in present[..<index].reversed() {
                if let found = result.firstIndex(of: previous) {
                    at = found + 1
                    break
                }
            }
            result.insert(id, at: at)
        }
        return result
    }

    static func isHidden(_ id: String, _ settings: BarSettings) -> Bool {
        if let app = app(of: id) { return settings.hiddenStatus[app] == true }
        return settings.hiddenTray[id] == true
    }

    static func split(_ settings: BarSettings, apps: [String], batteryPresent: Bool) -> (shown: [String], hidden: [String]) {
        let order = arrange(present(settings, apps: apps, batteryPresent: batteryPresent), stored: settings.trayOrder)
        return (order.filter { !isHidden($0, settings) }, order.filter { isHidden($0, settings) })
    }

    // Puts the item at a position among the shown items and takes it out from behind the chevron.
    static func moved(_ settings: BarSettings, id: String, toShownIndex index: Int, apps: [String],
                      batteryPresent: Bool) -> BarSettings {
        var value = hidden(settings, id: id, false)
        var (shown, hiddenIDs) = split(value, apps: apps, batteryPresent: batteryPresent)
        shown.removeAll { $0 == id }
        hiddenIDs.removeAll { $0 == id }
        shown.insert(id, at: min(max(0, index), shown.count))
        value.trayOrder = shown + hiddenIDs
        return value
    }

    static func hidden(_ settings: BarSettings, id: String, _ hide: Bool) -> BarSettings {
        var value = settings
        if let app = app(of: id) {
            if hide { value.hiddenStatus[app] = true } else { value.hiddenStatus.removeValue(forKey: app) }
        } else {
            if hide { value.hiddenTray[id] = true } else { value.hiddenTray.removeValue(forKey: id) }
        }
        return value
    }
}
