// HammerspoonImporter.swift
// Copies the Lua bar's stored settings and launcher image into OpenTaskbar on its first launch.
// Exists so switching from the Hammerspoon bar keeps every setting without re-entering it.
// Defines: HammerspoonImporter
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/HammerspoonImporter.swift.md
import Foundation

@MainActor
enum HammerspoonImporter {
    static let domain = "org.hammerspoon.Hammerspoon"
    static let appearanceKey = "bottomBarAppearance"
    static let restoreKey = "bottomBarRestoreLevels"
    static let doneKey = "importedFromHammerspoon"

    // Runs once: a stored OpenTaskbar value or the done flag both mean it already happened.
    static func importOnce() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: doneKey) || SettingsStore.shared.hasStoredValue { return }
        defaults.set(true, forKey: doneKey)

        guard let source = UserDefaults(suiteName: domain),
              var appearance = source.dictionary(forKey: appearanceKey) else {
            Log.settings.info("no Hammerspoon settings to import")
            return
        }

        if let levels = source.dictionary(forKey: restoreKey) {
            appearance["restoreLevels"] = levels
        }

        // The Lua bar height scaled every mark from a 26 point bar. The port lays out by the
        // Windows 10 taskbar metrics instead, so that number keeps its new default.
        appearance.removeValue(forKey: "barHeight")

        guard let imported = SettingsStore.decode(appearance) else {
            Log.settings.info("Hammerspoon settings did not decode")
            return
        }

        SettingsStore.shared.replace(imported)
        importLauncherImage()
        Log.settings.info("imported Hammerspoon settings")
    }

    // The Lua build kept an uploaded launcher image next to its config as start-icon.<ext>.
    private static func importLauncherImage() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hammerspoon")
        for ext in StartIconStore.extensions {
            let url = folder.appendingPathComponent("start-icon.\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                StartIconStore.installCustom(from: url)
                return
            }
        }
    }
}
