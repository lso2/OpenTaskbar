// DockMenuReader.swift
// Reads an application's Dock menu by opening it on its Dock item, and presses items in it later.
// Exists because an app's own jump list items are published only to the Dock.
// Defines: DockMenuReader, DockMenuNode
// Notes: docs/notes/app/Sources/OpenTaskbar/Menus/DockMenuReader.swift.md
import AppKit
import ApplicationServices

struct DockMenuNode: Sendable {
    let title: String
    let enabled: Bool
    let children: [DockMenuNode]?
}

@MainActor
enum DockMenuReader {
    static let cacheLife: TimeInterval = 30
    private static var cache: [String: (at: Date, nodes: [DockMenuNode])] = [:]

    // Nil means the app has no Dock item to read, which is the case for one that is not running
    // and not kept in the Dock.
    static func read(path: String) async -> [DockMenuNode]? {
        if let hit = cache[path], Date().timeIntervalSince(hit.at) < cacheLife { return hit.nodes }
        guard AXIsProcessTrusted(), let dockPID = dockPID else { return nil }
        let nodes = await harvest(dockPID: dockPID, path: path)
        if let nodes { cache[path] = (Date(), nodes) }
        return nodes
    }

    static func forget() { cache = [:] }

    static func press(path: String, trail: [String]) {
        guard let dockPID else { return }
        Task { @AXActor in
            guard let item = DockMenuReader.dockItem(dockPID: dockPID, path: path),
                  AX.perform(item, kAXShowMenuAction) else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard var list = DockMenuReader.menu(of: item).map({ AX.elements($0, kAXChildrenAttribute) }) else { return }
            var target: AXRef?
            for (step, title) in trail.enumerated() {
                target = list.first { AX.string($0, kAXTitleAttribute) == title }
                guard let found = target else { break }
                if step < trail.count - 1 {
                    guard let submenu = DockMenuReader.menu(of: found) else { target = nil; break }
                    list = AX.elements(submenu, kAXChildrenAttribute)
                }
            }
            if let target, AX.perform(target, kAXPressAction) { return }
            if let open = DockMenuReader.menu(of: item) { AX.perform(open, kAXCancelAction) }
        }
    }

    private static var dockPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    private static func harvest(dockPID: pid_t, path: String) async -> [DockMenuNode]? {
        await Task { @AXActor () -> [DockMenuNode]? in
            guard let item = DockMenuReader.dockItem(dockPID: dockPID, path: path),
                  AX.perform(item, kAXShowMenuAction) else { return nil }
            try? await Task.sleep(for: .milliseconds(450))
            guard let menu = DockMenuReader.menu(of: item) else { return nil }
            let nodes = DockMenuReader.nodes(menu, depth: 1)
            AX.perform(menu, kAXCancelAction)
            return nodes
        }.value
    }

    // Dock items carry their bundle's URL, which matches without depending on a localized name.
    @AXActor
    static func dockItem(dockPID: pid_t, path: String) -> AXRef? {
        let dock = AX.application(dockPID)
        AXUIElementSetMessagingTimeout(dock.element, 2)
        let wanted = URL(fileURLWithPath: path).standardizedFileURL.path
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        var byTitle: AXRef?
        for list in AX.elements(dock, kAXChildrenAttribute) {
            for item in AX.elements(list, kAXChildrenAttribute) {
                if let url = AX.value(item, kAXURLAttribute) as? URL,
                   url.standardizedFileURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ==
                    wanted.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
                    return item
                }
                if byTitle == nil, AX.string(item, kAXTitleAttribute) == name { byTitle = item }
            }
        }
        return byTitle
    }

    @AXActor
    static func menu(of item: AXRef) -> AXRef? {
        AX.elements(item, kAXChildrenAttribute).first { AX.string($0, kAXRoleAttribute) == kAXMenuRole }
    }

    @AXActor
    static func nodes(_ list: AXRef, depth: Int) -> [DockMenuNode] {
        AX.elements(list, kAXChildrenAttribute).map { entry in
            var children: [DockMenuNode]?
            if depth < 2, let submenu = menu(of: entry) { children = nodes(submenu, depth: depth + 1) }
            return DockMenuNode(title: AX.string(entry, kAXTitleAttribute) ?? "",
                                enabled: AX.bool(entry, kAXEnabledAttribute) ?? true,
                                children: children)
        }
    }
}
