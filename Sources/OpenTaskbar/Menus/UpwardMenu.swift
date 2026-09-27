// UpwardMenu.swift
// Builds an NSMenu from MenuEntry rows and opens it with its bottom edge on the bar's top edge.
// Exists because a menu opens downward from its top-left corner, so a bottom bar must place it by its measured height.
// Defines: UpwardMenu, MenuActionTarget
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/UpwardMenu.swift.md
import AppKit

// NSMenuItem holds its target weakly; the item's representedObject keeps this alive.
final class MenuActionTarget: NSObject {
    let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @MainActor @objc func run(_ sender: Any?) {
        action()
    }
}

@MainActor
enum UpwardMenu {
    static func build(_ entries: [MenuEntry]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in entries {
            if entry.isSeparator {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: entry.keyEquivalent)
            item.keyEquivalentModifierMask = entry.modifiers
            item.isEnabled = entry.enabled
            item.state = entry.checked ? .on : .off
            item.image = entry.image
            if let submenu = entry.submenu {
                item.submenu = build(submenu)
                item.isEnabled = true
            } else if let action = entry.action {
                let target = MenuActionTarget(action)
                item.target = target
                item.action = #selector(MenuActionTarget.run(_:))
                item.representedObject = target
            }
            menu.addItem(item)
        }
        return menu
    }

    // x is in the view's coordinates. The view is the flipped bar view, whose top edge is y 0,
    // so a top-left corner at minus the menu's height puts the menu's bottom on the bar.
    static func show(_ entries: [MenuEntry], x: CGFloat, in view: NSView) {
        guard !entries.isEmpty else { return }
        show(build(entries), x: x, in: view)
    }

    static func show(_ menu: NSMenu, x: CGFloat, in view: NSView) {
        let height = menu.size.height
        let top: CGFloat = view.isFlipped ? -height : view.bounds.height + height
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: top), in: view)
    }
}
