// SettingsBarTab.swift
// The Bar tab: row height, icon size, rows, text size, background, transparency, blur and auto-hide.
// Exists as the port of the Bar pane of bottombar-settings-page.lua, extended with the Windows sizing controls.
// Defines: SettingsBarTab
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsBarTab.swift.md
import SwiftUI

struct SettingsBarTab: View {
    @Bindable var model: SettingsModel

    // Small icons are the Windows 10 default: 30 point rows and 16 point icons. Large are 40 and 24.
    private var largeIcons: Binding<Bool> {
        Binding(get: { model.value.iconSize >= 20 }, set: { large in
            SettingsStore.shared.update { settings in
                settings.iconSize = large ? 24 : 16
                settings.barHeight = large ? 40 : 30
            }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsSection(title: "Size") {
                Toggle("Use large taskbar buttons", isOn: largeIcons)
                SliderRow(title: "Row height", value: model.binding(\.barHeight), range: 22...60, unit: " pt")
                SliderRow(title: "Icon size", value: model.binding(\.iconSize), range: 12...48, unit: " pt")
                Stepper("Rows: \(model.value.rows)", value: model.binding(\.rows), in: 1...3)
                Text("Drag the bar's top edge to change the number of rows.").font(.caption).foregroundStyle(.secondary)
                SliderRow(title: "Text size", value: model.binding(\.textScale), range: 70...250)
            }
            SettingsSection(title: "Look") {
                SliderRow(title: "Background", value: model.binding(\.brightness), range: 0...100)
                Toggle("Use transparency", isOn: model.binding(\.transparencyOn))
                SliderRow(title: "Transparency", value: model.binding(\.transparency), range: 0...100)
                    .disabled(!model.value.transparencyOn)
                Toggle("Blur behind the bar", isOn: model.binding(\.blur))
            }
            SettingsSection(title: "Behavior") {
                Toggle("Hide the bar until the pointer reaches the bottom edge", isOn: model.binding(\.autoHide))
                Picker("Button alignment", selection: model.binding(\.pinnedAlign)) {
                    Text("Left").tag("left")
                    Text("Center").tag("center")
                    Text("Right").tag("right")
                }
            }
            Button("Reset the bar sliders") {
                SettingsStore.shared.update { settings in
                    let defaults = BarSettings()
                    settings.barHeight = defaults.barHeight
                    settings.iconSize = defaults.iconSize
                    settings.rows = defaults.rows
                    settings.textScale = defaults.textScale
                    settings.brightness = defaults.brightness
                    settings.transparency = defaults.transparency
                }
            }
            Text("Defaults: small buttons, 30 pt rows, 16 pt icons, one row, text 100%, background 8%, transparency 6%. A background past 55% flips the type to dark.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
