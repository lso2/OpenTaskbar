// BarAutoHide.swift
// Hides each bar once the pointer leaves it and brings it back when the pointer reaches the screen's bottom edge.
// Exists as the port of the auto-hide loop in bottombar.lua, per screen and with its own switch.
// Defines: BarAutoHide
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarAutoHide.swift.md
import AppKit

@MainActor
final class BarAutoHide {
    static let shared = BarAutoHide()

    static let revealBand: CGFloat = 3
    static let firstHideDelay: TimeInterval = 2.5
    static let interval: TimeInterval = 0.15

    private var hidden: Set<CGDirectDisplayID> = []
    private var timer: Timer?
    private var armedAt = Date()

    func start() {
        armedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: BarAutoHide.interval, repeats: true) { _ in
            MainActor.assumeIsolated { BarAutoHide.shared.tick() }
        }
    }

    func panelsRebuilt() {
        hidden = []
        armedAt = Date()
    }

    func isHidden(_ panel: BarPanel) -> Bool { hidden.contains(panel.displayID) }

    func reveal(_ panel: BarPanel?) {
        guard let panel, hidden.remove(panel.displayID) != nil else { return }
        panel.orderFrontRegardless()
        panel.barView.needsDisplay = true
    }

    func revealAll() {
        for panel in BarController.shared.panels { reveal(panel) }
    }

    private func hide(_ panel: BarPanel) {
        guard !hidden.contains(panel.displayID) else { return }
        hidden.insert(panel.displayID)
        WindowPreview.shared.hide()
        BarTooltip.shared.hide()
        panel.orderOut(nil)
    }

    // Anything the bar opened, and any gesture that began on it, keeps it on screen.
    private var somethingOpen: Bool {
        LauncherReorder.shared.inGesture || BarResize.shared.active || StartPanel.shared.isOpen
            || PopupPanel.anyOpen || WindowPreview.shared.isShown
    }

    private func tick() {
        let panels = BarController.shared.panels
        guard SettingsStore.shared.current.autoHide else {
            revealAll()
            return
        }
        guard Date().timeIntervalSince(armedAt) > BarAutoHide.firstHideDelay else { return }

        let mouse = NSEvent.mouseLocation
        for panel in panels {
            guard let screen = panel.screenNow else { continue }
            let onScreen = screen.frame.minX <= mouse.x && mouse.x < screen.frame.maxX
                && screen.frame.minY <= mouse.y && mouse.y < screen.frame.maxY
            if hidden.contains(panel.displayID) {
                if onScreen && mouse.y <= panel.frame.minY + BarAutoHide.revealBand { reveal(panel) }
            } else if !somethingOpen && (!onScreen || mouse.y > panel.frame.maxY) {
                hide(panel)
            }
        }
    }
}
