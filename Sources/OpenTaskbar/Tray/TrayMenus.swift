// TrayMenus.swift
// The volume menu and the link that opens a System Settings page.
// Exists as the port of the volume menu builder in bottombar-tray.lua.
// Defines: TrayMenus
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/TrayMenus.swift.md
import AppKit

@MainActor
enum TrayMenus {
    static func openPane(_ url: String) -> @MainActor () -> Void {
        { if let link = URL(string: url) { NSWorkspace.shared.open(link) } }
    }

    static func volume() -> [MenuEntry] {
        let control = AudioControl.output
        control.refresh()
        guard let state = control.state else { return [.header("No output device")] }

        var items: [MenuEntry] = [
            .header(state.name), .separator,
            MenuEntry(state.muted ? "Unmute" : "Mute") { AudioControl.output.toggleMute() },
            .separator,
        ]
        for level in [0.0, 25, 50, 75, 100] {
            items.append(MenuEntry("\(Int(level))%", checked: abs(state.level - level) < 6) {
                AudioControl.output.setLevel(level)
            })
        }
        items.append(.separator)
        for device in CoreAudio.devices(input: false) {
            items.append(MenuEntry(device.name, checked: device.id == state.device) {
                AudioControl.output.setDefault(device.id)
            })
        }
        items.append(.separator)
        items.append(MenuEntry("Sound Settings", action: openPane("x-apple.systempreferences:com.apple.Sound-Settings.extension")))
        return items
    }
}
