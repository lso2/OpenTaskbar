// BarView.swift
// Draws one screen's bar from its layout and turns pointer events into actions on the zone under them.
// Exists as the native bar surface: it receives right clicks, drops and tracking events directly.
// Defines: BarView
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarView.swift.md
import AppKit

@MainActor
final class BarView: NSView {
    private(set) var layout = BarLayoutResult()
    private var hovered: BarZoneKind?
    private var pressed: BarZone?
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes(BarDropTarget.types)
    }

    required init?(coder: NSCoder) { nil }

    // Active always, so hover works while another app is frontmost and after a Space change.
    override func updateTrackingAreas() {
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
        super.updateTrackingAreas()
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let inputs = BarController.shared.inputs(width: bounds.width)
        layout = BarLayout.compute(inputs)
        BarController.shared.pageCount = layout.pageCount
        BarRenderer.draw(layout, palette: inputs.palette, bounds: bounds, hovered: hovered)
    }

    func screenRect(_ rect: NSRect) -> NSRect {
        guard let window else { return rect }
        return window.convertToScreen(convert(rect, to: nil))
    }

    // MARK: Pointer

    private func point(_ event: NSEvent) -> NSPoint { convert(event.locationInWindow, from: nil) }

    override func mouseDown(with event: NSEvent) {
        let at = point(event)
        WindowPreview.shared.hide()
        BarTooltip.shared.hide()

        if BarResize.shared.begins(at: at, in: self) { return }

        let zone = layout.zone(at: at)
        if StartPanel.shared.isOpen, zone?.kind != .start { StartPanel.shared.close() }
        guard let zone else { return }

        switch zone.kind {
        case .launcher(let index):
            pressed = zone
            let entries = BarController.shared.currentLaunchers
            if entries.indices.contains(index), entries[index].pinned {
                LauncherReorder.shared.press(index: index, at: at, geometry: layout.pinnedGeometry)
            }
        default:
            // Tray items act on release, since a press may become a drag.
            if let id = zone.kind.trayID {
                pressed = zone
                TrayDrag.shared.press(id, at: NSEvent.mouseLocation, from: .bar)
            } else {
                BarClickActions.perform(zone, in: self)
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let at = point(event)
        if BarResize.shared.active {
            BarResize.shared.drag(to: at, in: self)
            return
        }
        if TrayDrag.shared.drag(to: NSEvent.mouseLocation) {
            WindowPreview.shared.hide()
            return
        }
        if LauncherReorder.shared.drag(to: at) {
            WindowPreview.shared.hide()
            needsDisplay = true
        }
    }

    override func mouseUp(with event: NSEvent) {
        let at = point(event)
        if BarResize.shared.active {
            BarResize.shared.end()
            return
        }
        defer { pressed = nil }
        if TrayDrag.shared.id != nil {
            if TrayDrag.shared.release(at: NSEvent.mouseLocation), let pressed { BarClickActions.perform(pressed, in: self) }
            return
        }
        let onBar = bounds.insetBy(dx: 0, dy: -8).contains(at)

        switch LauncherReorder.shared.release(onBar: onBar) {
        case .reordered(let paths):
            PinnedStore.setOrder(paths)
            return
        case .unpinned(let path):
            PinnedStore.unpin(path)
            return
        case .click, .none:
            break
        }

        guard let pressed, let released = layout.zone(at: at) else { return }
        switch (pressed.kind, released.kind) {
        case (.launcher(let index), .launcher(let other)) where index == other:
            BarClickActions.launcherClicked(index, zone: pressed, in: self)
        default:
            break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let at = point(event)
        WindowPreview.shared.hide()
        BarTooltip.shared.hide()
        BarRightClickActions.perform(layout.zone(at: at), at: at, in: self)
    }

    override func mouseMoved(with event: NSEvent) {
        let at = point(event)
        BarResize.shared.updateCursor(at: at, in: self)
        let zone = layout.zone(at: at)
        if zone?.kind != hovered {
            hovered = zone?.kind
            needsDisplay = true
        }
        guard let zone else {
            WindowPreview.shared.hide()
            BarTooltip.shared.hide()
            return
        }
        if case .launcher(let index) = zone.kind {
            BarTooltip.shared.hide()
            WindowPreview.shared.hover(index, anchor: screenRect(zone.rect), bar: self)
            return
        }
        WindowPreview.shared.hide()
        BarTooltip.shared.hover(zone, anchor: screenRect(zone.rect), bar: self)
    }

    override func mouseEntered(with event: NSEvent) {
        Log.bar.debug("pointer entered the bar")
    }

    override func mouseExited(with event: NSEvent) {
        Log.bar.debug("pointer left the bar")
        hovered = nil
        needsDisplay = true
        NSCursor.arrow.set()
        BarTooltip.shared.hide()
        WindowPreview.shared.leaveBar()
    }

    // MARK: Dropping

    private func launcherPath(at point: NSPoint) -> String? {
        guard case .launcher(let index)? = layout.zone(at: point)?.kind else { return nil }
        let entries = BarController.shared.currentLaunchers
        return entries.indices.contains(index) ? entries[index].launcher.path : nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        BarAutoHide.shared.reveal(self.window as? BarPanel)
        return BarDropTarget.operation(sender, launcherPath: launcherPath(at: convert(sender.draggingLocation, from: nil)))
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        BarDropTarget.perform(sender, launcherPath: launcherPath(at: convert(sender.draggingLocation, from: nil)))
    }
}
