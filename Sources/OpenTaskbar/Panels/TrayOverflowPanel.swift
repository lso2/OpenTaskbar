// TrayOverflowPanel.swift
// The flyout above the chevron that holds the hidden tray items in a three column grid.
// Exists as the Windows 10 notification overflow: 40 point cells, #242424 fill, a #353535 edge, flush with the bar.
// Defines: TrayOverflowPanel, TrayOverflowView
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/TrayOverflowPanel.swift.md
import AppKit

@MainActor
final class TrayOverflowPanel {
    static let shared = TrayOverflowPanel()

    static let border: CGFloat = 0.67
    private let panel = PopupPanel(size: NSSize(width: 121, height: 41))
    private let view = TrayOverflowView(frame: .zero)

    private init() {
        panel.hasShadow = false
        panel.contentView = view
        // Hiding or showing an item while the flyout is open redraws it with the new contents.
        SettingsStore.shared.observe { if TrayOverflowPanel.shared.panel.isOpen { TrayOverflowPanel.shared.fill() } }
    }

    var isOpen: Bool { panel.isOpen }
    var frame: NSRect? { panel.isOpen ? panel.frame : nil }

    func toggle(above anchor: NSRect, bar: BarView) {
        if panel.isOpen {
            panel.dismiss()
            return
        }
        view.bar = bar
        view.anchor = anchor
        fill()
    }

    private func fill() {
        guard let bar = view.bar, let anchor = view.anchor else { return }
        let settings = SettingsStore.shared.current
        view.ids = TrayOrder.split(settings, apps: StatusItemMirror.shared.tiles.map(\.app),
                                   batteryPresent: Battery.shared.state.present).hidden
        let cell = TaskbarMetrics.flyoutCell
        let columns = TaskbarMetrics.flyoutColumns
        let rows = max(1, Int((Double(view.ids.count) / Double(columns)).rounded(.up)))
        let size = NSSize(width: (CGFloat(columns) * cell) + (2 * TrayOverflowPanel.border),
                          height: (CGFloat(rows) * cell) + TrayOverflowPanel.border)
        view.frame = NSRect(origin: .zero, size: size)
        view.needsDisplay = true
        panel.present(size: size, above: anchor, bar: bar, gap: 0)
    }

    func close() { panel.dismiss() }
}

@MainActor
final class TrayOverflowView: NSView {
    var ids: [String] = []
    weak var bar: BarView?
    var anchor: NSRect?
    private var hovered: Int?
    private var pressed: Int?
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    private func cellRect(_ index: Int) -> NSRect {
        let cell = TaskbarMetrics.flyoutCell
        let column = index % TaskbarMetrics.flyoutColumns
        let row = index / TaskbarMetrics.flyoutColumns
        return NSRect(x: TrayOverflowPanel.border + (CGFloat(column) * cell),
                      y: TrayOverflowPanel.border + (CGFloat(row) * cell), width: cell, height: cell)
    }

    private func index(at point: NSPoint) -> Int? {
        ids.indices.first { cellRect($0).contains(point) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 53 / 255, alpha: 1).setFill()
        bounds.fill()
        NSColor(white: 36 / 255, alpha: 1).setFill()
        NSRect(x: TrayOverflowPanel.border, y: TrayOverflowPanel.border,
               width: bounds.width - (2 * TrayOverflowPanel.border), height: bounds.height - TrayOverflowPanel.border).fill()

        guard !ids.isEmpty else {
            let label = NSAttributedString(string: "Nothing hidden", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(white: 1, alpha: 0.6)])
            let size = label.size()
            label.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
            return
        }

        let inputs = BarController.shared.inputs(width: bar?.bounds.width ?? 1280)
        let cells = TrayCells.cells(ids, inputs: inputs, color: .white, compact: true)
        for (index, cell) in cells.enumerated() {
            let rect = cellRect(index)
            if index == hovered {
                NSColor(white: 1, alpha: 0.1).setFill()
                rect.fill(using: .sourceOver)
            }
            for mark in cell.marks(rect) { BarRenderer.draw(mark) }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let found = index(at: convert(event.locationInWindow, from: nil))
        if found != hovered {
            hovered = found
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovered = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let index = index(at: convert(event.locationInWindow, from: nil)) else { return }
        pressed = index
        TrayDrag.shared.press(ids[index], at: NSEvent.mouseLocation, from: .flyout)
    }

    override func mouseDragged(with event: NSEvent) {
        _ = TrayDrag.shared.drag(to: NSEvent.mouseLocation)
    }

    // A click runs the item's action anchored at its cell, as clicking it on the bar would.
    override func mouseUp(with event: NSEvent) {
        defer { pressed = nil }
        guard let pressed, ids.indices.contains(pressed) else { return }
        let id = ids[pressed]
        let rect = cellRect(pressed)
        guard TrayDrag.shared.release(at: NSEvent.mouseLocation), let kind = BarZoneKind.tray(id), let bar,
              let window else { return }
        let anchor = window.convertToScreen(convert(rect, to: nil))
        let local = bar.convert(bar.window?.convertPoint(fromScreen: anchor.origin) ?? .zero, from: nil)
        TrayOverflowPanel.shared.close()
        BarClickActions.perform(kind, anchor: anchor, x: local.x, in: bar)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = index(at: point), let kind = BarZoneKind.tray(ids[index]), let bar, let window else { return }
        let anchor = window.convertToScreen(convert(cellRect(index), to: nil))
        let entries = BarItemMenus.entries(for: kind, anchor: anchor, in: bar, hidden: true) ?? []
        UpwardMenu.build(entries).popUp(positioning: nil, at: point, in: self)
    }
}
