// BarPanel.swift
// The borderless, non-activating panel that holds one screen's bar along its bottom edge.
// Exists so each screen has a bar window that never takes focus and appears on every Space.
// Defines: BarPanel
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarPanel.swift.md
import AppKit

@MainActor
final class BarPanel: NSPanel {
    let displayID: CGDirectDisplayID
    let barView: BarView
    let background: BarBackground

    // One level above the Dock, so a Dock that slides up never covers the bar.
    static let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)

    init(screen: NSScreen) {
        displayID = BarPanel.displayID(of: screen)
        let frame = BarPanel.frame(on: screen)
        background = BarBackground(frame: NSRect(origin: .zero, size: frame.size))
        barView = BarView(frame: NSRect(origin: .zero, size: frame.size))
        barView.autoresizingMask = [.width, .height]

        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        isFloatingPanel = true
        level = BarPanel.level
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        contentView = background
        background.addSubview(barView)
        background.apply(SettingsStore.shared.current)
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var screenNow: NSScreen? {
        NSScreen.screens.first { BarPanel.displayID(of: $0) == displayID }
    }

    // Inside the screen's usable frame, which already leaves out the Dock.
    static func frame(on screen: NSScreen) -> NSRect {
        let area = screen.visibleFrame
        let height = TaskbarMetrics(SettingsStore.shared.current).height
        return NSRect(x: area.minX, y: area.minY, width: area.width, height: height)
    }

    func fit() {
        guard let screen = screenNow else { return }
        setFrame(BarPanel.frame(on: screen), display: true)
        background.apply(SettingsStore.shared.current)
        barView.needsDisplay = true
    }
}
