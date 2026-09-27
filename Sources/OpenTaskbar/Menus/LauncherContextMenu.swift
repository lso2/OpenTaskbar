// LauncherContextMenu.swift
// Assembles a pinned launcher's right click menu from the app's own Dock menu items.
// Exists as the port of the menu assembly in bottombar-appcontext.lua.
// Defines: LauncherContextMenu
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/LauncherContextMenu.swift.md
import AppKit

@MainActor
enum LauncherContextMenu {
    static let standard: Set<String> = ["Options", "Quit", "Force Quit"]

    static func entries(for launcher: Launcher, dockItems: [DockMenuNode]?) -> [MenuEntry] {
        let path = launcher.path
        let unpin = MenuEntry("Unpin from the taskbar") { PinnedStore.unpin(path) }
        let reveal = MenuEntry("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }

        var menu: [MenuEntry] = [.header(launcher.title), .separator]

        guard let items = dockItems else {
            menu.append(MenuEntry("Open") { PinnedStore.launch(path) })
            menu.append(.separator)
            menu.append(MenuEntry("Options", submenu: [reveal, .separator, unpin]))
            return menu
        }

        var options: [MenuEntry] = []
        var quit: DockMenuNode?
        var forceQuit: DockMenuNode?
        var body: [DockMenuNode] = []

        // The Dock's first row repeats the app's name; the rest are the app's own items.
        for (index, item) in items.enumerated() where index > 0 {
            if item.title == "Options", let children = item.children {
                options = convert(children, path: path, trail: ["Options"])
            } else if item.title == "Quit" {
                quit = item
            } else if item.title == "Force Quit" {
                forceQuit = item
            } else if !standard.contains(item.title) {
                body.append(item)
            }
        }

        menu.append(contentsOf: convert(body, path: path, trail: []))
        if forceQuit != nil {
            options.append(.separator)
            options.append(MenuEntry("Force Quit") { DockMenuReader.press(path: path, trail: ["Force Quit"]) })
        }
        options.append(.separator)
        options.append(reveal)
        options.append(unpin)

        menu.append(.separator)
        menu.append(MenuEntry("Options", submenu: options))

        if quit != nil {
            menu.append(.separator)
            menu.append(MenuEntry("Quit") { DockMenuReader.press(path: path, trail: ["Quit"]) })
        }
        return menu
    }

    private static func convert(_ nodes: [DockMenuNode], path: String, trail: [String]) -> [MenuEntry] {
        nodes.map { node in
            if node.title.isEmpty { return .separator }
            let itemTrail = trail + [node.title]
            if let children = node.children {
                return MenuEntry(node.title, submenu: convert(children, path: path, trail: itemTrail))
            }
            return MenuEntry(node.title, enabled: node.enabled) {
                DockMenuReader.press(path: path, trail: itemTrail)
            }
        }
    }
}
