// StatusItemMirror.swift
// Lists third-party menu bar status items, draws a tile for each, and presses the real item on click.
// Exists because only the owning process can open a status item's menu, so the bar mirrors the item.
// Defines: StatusItemTile, StatusItemMirror
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/StatusItemMirror.swift.md
import AppKit
import ApplicationServices

struct StatusItemTile {
    let app: String
    let pid: pid_t
    let ref: AXRef
    let icon: NSImage
    let glyph: StatusGlyph?     // the item's own pixels, from StatusItemGlyphs
    let letter: String
    let x: CGFloat
    static let width: CGFloat = 22
}

@MainActor
final class StatusItemMirror {
    static let shared = StatusItemMirror()

    // Control Center's items are rebuilt natively on the bar; Spotlight has its own search mark.
    static let skipped: Set<String> = ["com.apple.controlcenter", "com.apple.Spotlight", "com.apple.systemuiserver",
                                       "com.apple.TextInputMenuAgent", "com.plexpixel.OpenTaskbar",
                                       "org.hammerspoon.Hammerspoon"]

    private(set) var tiles: [StatusItemTile] = []
    private var scannedAt = Date.distantPast
    private var scanning = false
    private var observers: [@MainActor () -> Void] = []

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }

    func invalidate() { scannedAt = .distantPast }

    // At most one scan every 15 seconds, each on AXActor.
    func scan() {
        guard !scanning, Date().timeIntervalSince(scannedAt) > 15, AXIsProcessTrusted() else { return }
        scanning = true
        let apps = NSWorkspace.shared.runningApplications.compactMap { app -> (pid_t, String, NSImage)? in
            guard let bundle = app.bundleIdentifier, !StatusItemMirror.skipped.contains(bundle),
                  let name = app.localizedName else { return nil }
            return (app.processIdentifier, name, app.icon ?? NSImage())
        }
        let pids = apps.map(\.0)
        Task { @AXActor in
            var found: [(pid: pid_t, ref: AXRef, x: CGFloat)] = []
            for pid in pids {
                let app = AX.application(pid)
                guard let extras = AX.element(app, kAXExtrasMenuBarAttribute),
                      let first = AX.elements(extras, kAXChildrenAttribute).first else { continue }
                found.append((pid, first, AX.point(first)?.x ?? 0))
            }
            let sorted = found.sorted { $0.x < $1.x }
            await MainActor.run { StatusItemMirror.shared.finishScan(sorted, apps: apps) }
        }
    }

    private func finishScan(_ found: [(pid: pid_t, ref: AXRef, x: CGFloat)], apps: [(pid_t, String, NSImage)]) {
        let names = Dictionary(apps.map { ($0.0, ($0.1, $0.2)) }, uniquingKeysWith: { first, _ in first })
        tiles = found.compactMap { entry in
            guard let (name, icon) = names[entry.pid] else { return nil }
            return StatusItemTile(app: name, pid: entry.pid, ref: entry.ref, icon: icon,
                                  glyph: StatusItemGlyphs.shared.glyph(for: name),
                                  letter: String(name.prefix(1)).uppercased(), x: entry.x)
        }
        scannedAt = Date()
        scanning = false
        Log.tray.debug("status items: \(self.tiles.map(\.app).joined(separator: ", "), privacy: .public)")
        for observer in observers { observer() }
        if !SettingsStore.shared.current.whiteStatusMarks {
            StatusItemGlyphs.shared.capture(tiles.map { ($0.app, $0.x) }) { StatusItemMirror.shared.refreshGlyphs() }
        }
    }

    func tile(_ app: String) -> StatusItemTile? {
        tiles.first { $0.app == app }
    }

    func press(_ tile: StatusItemTile) {
        let ref = tile.ref
        Task { @AXActor in AX.perform(ref, kAXPressAction) }
    }

    func tooltip(_ tile: StatusItemTile) async -> String {
        let ref = tile.ref
        let said = await Task { @AXActor () -> String? in
            for attribute in [kAXDescriptionAttribute, kAXHelpAttribute, kAXTitleAttribute] {
                if let value = AX.string(ref, attribute), !value.isEmpty { return value }
            }
            return nil
        }.value
        guard let said, said != tile.app else { return tile.app }
        return "\(tile.app), \(said)"
    }

    private func refreshGlyphs() {
        tiles = tiles.map { tile in
            StatusItemTile(app: tile.app, pid: tile.pid, ref: tile.ref, icon: tile.icon,
                           glyph: StatusItemGlyphs.shared.glyph(for: tile.app), letter: tile.letter, x: tile.x)
        }
        for observer in observers { observer() }
    }
}
