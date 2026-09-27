// SettingsItemsTab.swift
// The Items tab: a switch for every bar item and tray item, the date format, the tray mark style and the clock layout.
// Exists as the port of the Items pane of bottombar-settings-page.lua.
// Defines: SettingsItemsTab
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsItemsTab.swift.md
import SwiftUI

struct SettingsItemsTab: View {
    @Bindable var model: SettingsModel

    static let labels: [String: String] = [
        "appMenu": "Application menus", "pinned": "Pinned launchers", "running": "Running apps that are not pinned",
        "taskView": "Mission Control button", "displayOff": "Display off button", "calculator": "Calculator",
        "tools": "Tools pane", "search": "Search button", "volume": "Volume", "microphone": "Microphone",
        "keyboardBrightness": "Keyboard brightness", "displayBrightness": "Screen brightness", "wifi": "Wi-Fi",
        "battery": "Battery icon", "batteryText": "Battery percentage", "spotlight": "Spotlight",
        "controlCenter": "Control Center", "date": "Date", "time": "Time",
        "notifications": "Notification Center button", "statusItems": "Mirrored status items",
        "showDesktop": "Show desktop strip",
    ]

    static let dateFormats: [(value: String, label: String)] = [
        ("%-m/%-d/%Y", "9/26/2026"), ("%a %b %d", "Sat Sep 26"), ("%b %d", "Sep 26"),
        ("%m/%d/%Y", "09/26/2026"), ("%Y-%m-%d", "2026-09-26"), ("%A, %B %d", "Saturday, September 26"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(title: "Shown on the bar") {
                ForEach(BarSettings.items, id: \.self) { item in
                    Toggle(SettingsItemsTab.labels[item] ?? item, isOn: model.show(item))
                }
            }
            SettingsSection(title: "Clock") {
                Picker("Date format", selection: model.binding(\.dateFormat)) {
                    ForEach(SettingsItemsTab.dateFormats, id: \.value) { format in
                        Text(format.label).tag(format.value)
                    }
                }
                Picker("Clock layout", selection: model.binding(\.clockStacked)) {
                    Text("Time above date").tag(true)
                    Text("Side by side").tag(false)
                }
                Toggle("24 hour time (system wide)", isOn: model.hour24Binding)
            }
            SettingsSection(title: "Tray") {
                ForEach(trayIDs, id: \.self) { id in
                    Toggle(trayLabel(id), isOn: onTaskbar(id))
                }
                Text("Off puts the item behind the chevron. Drag items along the tray to reorder them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsSection(title: "Status items") {
                Picker("Mirrored items", selection: model.binding(\.whiteStatusMarks)) {
                    Text("Menu bar icon").tag(false)
                    Text("White letter").tag(true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Every tray item in its tray order, shown or hidden.
    private var trayIDs: [String] {
        let split = TrayOrder.split(model.value, apps: StatusItemMirror.shared.tiles.map(\.app),
                                    batteryPresent: Battery.shared.state.present)
        return TrayOrder.arrange(split.shown + split.hidden, stored: model.value.trayOrder)
    }

    private func trayLabel(_ id: String) -> String {
        TrayOrder.app(of: id) ?? SettingsItemsTab.labels[id] ?? id
    }

    private func onTaskbar(_ id: String) -> Binding<Bool> {
        Binding(get: { !TrayOrder.isHidden(id, model.value) },
                set: { on in SettingsStore.shared.update { $0 = TrayOrder.hidden($0, id: id, !on) } })
    }
}
