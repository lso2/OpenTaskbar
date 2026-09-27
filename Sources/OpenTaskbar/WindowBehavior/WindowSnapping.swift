// WindowSnapping.swift
// Command+Option with an arrow snaps the focused window to a half or the full screen, and back.
// Exists as the port of the snapping in init.lua, which keeps the bottom bar uncovered.
// Defines: WindowSnapping
// Notes: docs/notes/app/Sources/OpenTaskbar/WindowBehavior/WindowSnapping.swift.md
import AppKit
import ApplicationServices

@MainActor
enum WindowSnapping {
    private static let mods = HotKey.command | HotKey.option
    private static var previous: [AXRef: CGRect] = [:]

    static let module = HotKeyModule([
        HotKeyModule.Binding(HotKey(keyCode: HotKey.left, modifiers: mods), { snap(x: 0, width: 0.5) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.right, modifiers: mods), { snap(x: 0.5, width: 0.5) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.up, modifiers: mods), { snap(x: 0, width: 1) }),
        HotKeyModule.Binding(HotKey(keyCode: HotKey.down, modifiers: mods), { restore() }),
    ])

    // The usable frame of the screen holding the window, in accessibility coordinates (top-left
    // origin on the primary screen), less the bar's height along the bottom.
    private static func usable(for window: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first else { return nil }
        let center = NSPoint(x: window.midX, y: primary.frame.maxY - window.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? primary
        let area = screen.visibleFrame
        let bar = TaskbarMetrics(SettingsStore.shared.current).height
        return CGRect(x: area.minX, y: primary.frame.maxY - area.maxY, width: area.width, height: area.height - bar)
    }

    private static func focused() async -> (AXRef, CGRect)? {
        await Task { @AXActor () -> (AXRef, CGRect)? in
            guard let app = AX.element(AX.systemWide, kAXFocusedApplicationAttribute),
                  let window = AX.element(app, kAXFocusedWindowAttribute), let frame = AX.frame(window) else { return nil }
            return (window, frame)
        }.value
    }

    private static func apply(_ window: AXRef, _ frame: CGRect) {
        Task { @AXActor in
            AX.setPoint(window, kAXPositionAttribute, frame.origin)
            AX.setSize(window, kAXSizeAttribute, frame.size)
        }
    }

    private static func snap(x: CGFloat, width: CGFloat) {
        Task { @MainActor in
            guard let (window, frame) = await focused(), let area = usable(for: frame) else { return }
            previous[window] = frame
            apply(window, CGRect(x: area.minX + (area.width * x), y: area.minY, width: area.width * width, height: area.height))
        }
    }

    // Back to where it was before snapping, or centered at a workable size when nothing is stored.
    private static func restore() {
        Task { @MainActor in
            guard let (window, frame) = await focused(), let area = usable(for: frame) else { return }
            if let saved = previous.removeValue(forKey: window) {
                apply(window, saved)
            } else {
                apply(window, CGRect(x: area.minX + (area.width * 0.15), y: area.minY + (area.height * 0.1),
                                     width: area.width * 0.7, height: area.height * 0.8))
            }
        }
    }
}
