// AppMenuReader.swift
// Reads the frontmost application's menu bar through accessibility and opens any menu of it upward.
// Exists so the bar carries the real menus at full depth, with real enabled and checked state.
// Defines: AppMenuReader, AppMenuTop, AppMenuNode
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/AppMenuReader.swift.md
import AppKit
import ApplicationServices

struct AppMenuTop: Sendable, Equatable {
    let title: String
    let ref: AXRef
}

struct AppMenuNode: Sendable {
    let title: String
    let enabled: Bool
    let checked: Bool
    let commandKey: String
    let commandModifiers: Int
    let children: [AppMenuNode]?
    let ref: AXRef
}

@MainActor
final class AppMenuReader {
    static let shared = AppMenuReader()

    private(set) var pid: pid_t?
    private(set) var menus: [AppMenuTop] = []
    private var observers: [@MainActor () -> Void] = []
    private var generation = 0

    func observe(_ observer: @escaping @MainActor () -> Void) {
        observers.append(observer)
    }

    func start() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { AppMenuReader.shared.refresh(pid) }
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            refresh(front.processIdentifier)
        }
    }

    // OpenTaskbar's own windows leave the previous application's menus on the bar.
    func refresh(_ pid: pid_t) {
        guard pid != ProcessInfo.processInfo.processIdentifier, AXIsProcessTrusted(),
              SettingsStore.shared.current.shows("appMenu") else { return }
        generation += 1
        let asked = generation
        Task { @AXActor in
            let found = AppMenuReader.readTop(pid)
            await MainActor.run {
                let reader = AppMenuReader.shared
                guard reader.generation == asked else { return }
                reader.pid = pid
                if reader.menus != found {
                    Log.menus.debug("menus for pid \(pid): \(found.map(\.title).joined(separator: ", "), privacy: .public)")
                    reader.menus = found
                    for observer in reader.observers { observer() }
                }
            }
        }
    }

    func open(_ index: Int, x: CGFloat, in view: NSView) {
        guard menus.indices.contains(index) else { return }
        let top = menus[index].ref
        Task { @AXActor in
            let nodes = AppMenuReader.readChildren(top, depth: 0)
            await MainActor.run {
                UpwardMenu.show(AppMenuReader.entries(nodes), x: x, in: view)
            }
        }
    }

    // The first menu bar child is always the Apple menu, which the bar leaves out.
    @AXActor
    static func readTop(_ pid: pid_t) -> [AppMenuTop] {
        let app = AX.application(pid)
        guard let bar = AX.element(app, kAXMenuBarAttribute) else { return [] }
        return AX.elements(bar, kAXChildrenAttribute).dropFirst().compactMap { item in
            guard let title = AX.string(item, kAXTitleAttribute), !title.isEmpty else { return nil }
            return AppMenuTop(title: title, ref: item)
        }
    }

    @AXActor
    static func readChildren(_ item: AXRef, depth: Int) -> [AppMenuNode] {
        guard depth < 6,
              let menu = AX.elements(item, kAXChildrenAttribute).first(where: {
                  AX.string($0, kAXRoleAttribute) == kAXMenuRole
              }) else { return [] }

        return AX.elements(menu, kAXChildrenAttribute).map { child in
            let submenu = readChildren(child, depth: depth + 1)
            return AppMenuNode(
                title: AX.string(child, kAXTitleAttribute) ?? "",
                enabled: AX.bool(child, kAXEnabledAttribute) ?? true,
                checked: !(AX.string(child, kAXMenuItemMarkCharAttribute) ?? "").isEmpty,
                commandKey: AX.string(child, kAXMenuItemCmdCharAttribute) ?? "",
                commandModifiers: (AX.value(child, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0,
                children: submenu.isEmpty ? nil : submenu,
                ref: child)
        }
    }

    static func entries(_ nodes: [AppMenuNode]) -> [MenuEntry] {
        nodes.map { node in
            if node.title.isEmpty { return .separator }
            if let children = node.children { return MenuEntry(node.title, submenu: entries(children)) }
            let ref = node.ref
            var entry = MenuEntry(node.title, enabled: node.enabled, checked: node.checked) {
                Task { @AXActor in AX.perform(ref, kAXPressAction) }
            }
            if node.commandKey.count == 1 {
                entry.keyEquivalent = node.commandKey.lowercased()
                entry.modifiers = modifiers(node.commandModifiers)
            }
            return entry
        }
    }

    // kAXMenuItemModifier bits: 1 Shift, 2 Option, 4 Control, 8 no Command.
    static func modifiers(_ bits: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if bits & 8 == 0 { flags.insert(.command) }
        if bits & 1 != 0 { flags.insert(.shift) }
        if bits & 2 != 0 { flags.insert(.option) }
        if bits & 4 != 0 { flags.insert(.control) }
        return flags
    }
}
