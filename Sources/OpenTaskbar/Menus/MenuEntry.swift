// MenuEntry.swift
// One row of a popup menu: title, state, submenu and the closure it runs when chosen.
// Exists so readers of other apps' menus and OpenTaskbar's own menus hand UpwardMenu one type.
// Defines: MenuEntry
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/MenuEntry.swift.md
import AppKit

struct MenuEntry {
    var title: String
    var enabled = true
    var checked = false
    var isSeparator = false
    var submenu: [MenuEntry]?
    var keyEquivalent = ""
    var modifiers: NSEvent.ModifierFlags = []
    var image: NSImage?
    var action: (@MainActor () -> Void)?

    init(_ title: String, enabled: Bool = true, checked: Bool = false,
         action: (@MainActor () -> Void)? = nil) {
        self.title = title
        self.enabled = enabled
        self.checked = checked
        self.action = action
    }

    init(_ title: String, submenu: [MenuEntry]) {
        self.title = title
        self.submenu = submenu
    }

    static var separator: MenuEntry {
        var entry = MenuEntry("")
        entry.isSeparator = true
        return entry
    }

    // A label row that names what the menu is about and does nothing.
    static func header(_ title: String) -> MenuEntry {
        MenuEntry(title, enabled: false)
    }
}
