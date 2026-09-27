// SettingsBackup.swift
// Writes every setting to one JSON file and reads it back, in the format the Lua build used.
// Exists so a backup made by either build restores into the other, launcher image included.
// Defines: SettingsBackup
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsBackup.swift.md
import AppKit
import UniformTypeIdentifiers

@MainActor
enum SettingsBackup {
    static let fileName = "winbar-settings.json"

    static func payload() -> [String: Any] {
        let settings = SettingsStore.shared.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var payload: [String: Any] = [
            "winbar": 1,
            "written": formatter.string(from: Date()),
            "hour24": ClockPreference.hour24,
            "settings": SettingsStore.propertyList(settings) ?? [:],
        ]

        if let url = StartIconStore.currentURL(for: settings.startIconName),
           let data = try? Data(contentsOf: url) {
            payload["startIcon"] = ["extension": url.pathExtension, "data": data.base64EncodedString()]
        }
        return payload
    }

    // Returns false for anything that is not a backup, so a wrong file changes nothing.
    @discardableResult
    static func apply(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stored = object["settings"] as? [String: Any],
              let settings = SettingsStore.decode(stored) else { return false }

        SettingsStore.shared.replace(settings)

        if let hour24 = object["hour24"] as? Bool { ClockPreference.setHour24(hour24) }

        if let icon = object["startIcon"] as? [String: Any],
           let encoded = icon["data"] as? String,
           let bytes = Data(base64Encoded: encoded) {
            let ext = (icon["extension"] as? String) ?? "png"
            StartIconStore.installCustom(data: bytes, extension: ext)
            SettingsStore.shared.update { $0.startIconName = "" }
        }
        return true
    }

    static func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [.json]
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: payload(),
                                                     options: [.prettyPrinted, .sortedKeys]) else { return }
        do {
            try data.write(to: url)
            Log.settings.info("settings written to \(url.path, privacy: .public)")
        } catch {
            alert("The file could not be written: \(error.localizedDescription)")
        }
    }

    static func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url), apply(data) else {
            alert("That file does not hold bar settings.")
            return
        }
    }

    private static func alert(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.runModal()
    }
}
