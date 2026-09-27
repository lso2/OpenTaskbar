// SettingsBackupTab.swift
// The Backup tab: export every setting to one JSON file and import it back.
// Exists as the port of the Backup pane of bottombar-settings-page.lua.
// Defines: SettingsBackupTab
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/SettingsBackupTab.swift.md
import SwiftUI

struct SettingsBackupTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Export to a file") { SettingsBackup.export() }
                Button("Import from a file") { SettingsBackup.importFromFile() }
            }
            Text("One JSON file holds every setting on the other tabs, the pinned launchers, the hidden status items, the two Start panel names and the launcher image. Export writes winbar-settings.json, the same file the Hammerspoon build writes, and Import reads files from either build.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
