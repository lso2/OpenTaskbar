// BarResize.swift
// Dragging the bar's top edge up or down to give it one, two or three rows.
// Exists because the Windows taskbar resizes by its edge, and rows are how its buttons wrap.
// Defines: BarResize
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarResize.swift.md
import AppKit

@MainActor
final class BarResize {
    static let shared = BarResize()

    // The grab band along the top edge, in points.
    static let band: CGFloat = 3

    private(set) var active = false
    private var startScreenY: CGFloat = 0
    private var startRows = 1

    func updateCursor(at point: NSPoint, in view: BarView) {
        if point.y <= BarResize.band || active { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
    }

    func begins(at point: NSPoint, in view: BarView) -> Bool {
        guard point.y <= BarResize.band else { return false }
        active = true
        startScreenY = NSEvent.mouseLocation.y
        startRows = SettingsStore.shared.current.rows
        return true
    }

    // Each row's height of travel adds or removes a row, settling at the nearest whole count.
    func drag(to point: NSPoint, in view: BarView) {
        guard active else { return }
        let settings = SettingsStore.shared.current
        let rowStep = CGFloat(settings.barHeight) + 2
        let travel = NSEvent.mouseLocation.y - startScreenY
        let wanted = min(3, max(1, startRows + Int((travel / rowStep).rounded())))
        if wanted != settings.rows {
            SettingsStore.shared.update { $0.rows = wanted }
        }
    }

    func end() {
        active = false
        NSCursor.arrow.set()
    }
}
