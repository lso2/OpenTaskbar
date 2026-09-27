// BarRightClickActions.swift
// Opens the right click menu for each part of the bar.
// Exists so a launcher gets its Dock menu, every other item its own menu, and Start, empty bar and the chevron the OpenTaskbar menu.
// Defines: BarRightClickActions
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarRightClickActions.swift.md
import AppKit

@MainActor
enum BarRightClickActions {
    static func perform(_ zone: BarZone?, at point: NSPoint, in view: BarView) {
        guard let zone else {
            UpwardMenu.show(StartContextMenu.entries(), x: min(point.x, view.bounds.width - 220), in: view)
            return
        }
        switch zone.kind {
        case .launcher(let index):
            let entries = BarController.shared.currentLaunchers
            guard entries.indices.contains(index) else { return }
            let entry = entries[index]
            Task { @MainActor in
                let items = await DockMenuReader.read(path: entry.launcher.path)
                var menu = LauncherContextMenu.entries(for: entry.launcher, dockItems: items)
                if !entry.pinned {
                    let path = entry.launcher.path
                    menu.insert(contentsOf: [MenuEntry("Pin to taskbar") { PinnedStore.pin(path) }, .separator], at: 2)
                }
                UpwardMenu.show(menu, x: zone.rect.minX, in: view)
            }
        case .menu(let index):
            AppMenuReader.shared.open(index, x: zone.rect.minX, in: view)
        default:
            if let entries = BarItemMenus.entries(for: zone.kind, anchor: view.screenRect(zone.rect), in: view) {
                UpwardMenu.show(entries, x: min(zone.rect.minX, view.bounds.width - 220), in: view)
            } else {
                UpwardMenu.show(StartContextMenu.entries(), x: min(zone.rect.minX, view.bounds.width - 220), in: view)
            }
        }
    }
}
