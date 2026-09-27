// TrayDrag.swift
// Drags a tray item along the tray to reorder it, onto the chevron or into its flyout to hide it, and back out to show it.
// Exists as the Windows 10 notification area's drag behavior, shared by the bar and the chevron flyout.
// Defines: TrayDrag
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/TrayDrag.swift.md
import AppKit

@MainActor
final class TrayDrag {
    static let shared = TrayDrag()
    static let threshold: CGFloat = 4
    static let chevronDelay: TimeInterval = 0.45

    enum Source { case bar, flyout }

    private(set) var id: String?
    private var source: Source = .bar
    private var origin: NSPoint = .zero
    private(set) var active = false
    private let ghost: NSPanel
    private let ghostView = NSImageView()
    private var chevronTimer: Timer?

    private init() {
        ghost = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        ghost.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        ghost.ignoresMouseEvents = true
        ghost.backgroundColor = .clear
        ghost.isOpaque = false
        ghost.hasShadow = false
        ghost.alphaValue = 0.85
        ghost.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ghost.contentView = ghostView
    }

    // Points are in screen coordinates throughout, since a drag crosses from the flyout to the bar.
    func press(_ id: String, at point: NSPoint, from source: Source) {
        self.id = id
        self.source = source
        origin = point
        active = false
    }

    // Whether a drag is under way; below the threshold the press is still a click.
    func drag(to point: NSPoint) -> Bool {
        guard let id else { return false }
        if !active {
            guard hypot(point.x - origin.x, point.y - origin.y) >= TrayDrag.threshold else { return false }
            active = true
            BarTooltip.shared.hide()
            showGhost(id, at: point)
        }
        ghost.setFrameOrigin(NSPoint(x: point.x - (ghost.frame.width / 2), y: point.y - (ghost.frame.height / 2)))
        preview(at: point)
        watchChevron(at: point)
        return true
    }

    // True when the press was a click. A drop on the chevron or the flyout hides the item; a drop
    // on the tray puts it where the preview showed it; anywhere else leaves everything as it was.
    func release(at point: NSPoint) -> Bool {
        defer { reset() }
        guard let id else { return false }
        guard active else { return true }
        let apps = StatusItemMirror.shared.tiles.map(\.app)
        let battery = Battery.shared.state.present
        if overFlyout(point) || chevron(at: point) != nil {
            if source == .bar { SettingsStore.shared.update { $0 = TrayOrder.hidden($0, id: id, true) } }
        } else if let preview = BarController.shared.trayDrag {
            SettingsStore.shared.update {
                $0 = TrayOrder.moved($0, id: id, toShownIndex: preview.index, apps: apps, batteryPresent: battery)
            }
        }
        if source == .flyout || TrayOverflowPanel.shared.isOpen { TrayOverflowPanel.shared.close() }
        return false
    }

    private func reset() {
        id = nil
        active = false
        ghost.orderOut(nil)
        chevronTimer?.invalidate()
        chevronTimer = nil
        if BarController.shared.trayDrag != nil {
            BarController.shared.trayDrag = nil
            BarController.shared.redraw()
        }
    }

    private func showGhost(_ id: String, at point: NSPoint) {
        guard let panel = BarController.shared.panels.first,
              let image = TrayCells.image(id, inputs: BarController.shared.inputs(width: panel.barView.bounds.width)) else { return }
        ghostView.image = image
        ghost.setContentSize(image.size)
        ghostView.frame = NSRect(origin: .zero, size: image.size)
        ghost.setFrameOrigin(NSPoint(x: point.x - (image.size.width / 2), y: point.y - (image.size.height / 2)))
        ghost.orderFrontRegardless()
    }

    private func bar(at point: NSPoint) -> (panel: BarPanel, local: NSPoint)? {
        guard let panel = BarController.shared.panels.first(where: { $0.frame.insetBy(dx: 0, dy: -8).contains(point) })
        else { return nil }
        let inWindow = panel.convertPoint(fromScreen: point)
        return (panel, panel.barView.convert(inWindow, from: nil))
    }

    private func chevron(at point: NSPoint) -> (view: BarView, rect: NSRect)? {
        guard let (panel, local) = bar(at: point), let rect = panel.barView.layout.chevronRect, rect.contains(local)
        else { return nil }
        return (panel.barView, rect)
    }

    private func overFlyout(_ point: NSPoint) -> Bool {
        TrayOverflowPanel.shared.frame?.contains(point) ?? false
    }

    // The tray runs from the chevron to the clock. Over it, the item previews at the position of
    // the items the pointer has passed; one row counts by x, more rows take the slot under the pointer.
    private func preview(at point: NSPoint) {
        guard let id else { return }
        var wanted: TrayDragPreview?
        if let (panel, local) = bar(at: point) {
            let layout = panel.barView.layout
            let slots = layout.traySlots
            let left = layout.chevronRect?.maxX ?? slots.first?.rect.minX ?? 0
            let right = layout.clockRect.width > 0 ? layout.clockRect.minX : (slots.last?.rect.maxX ?? left)
            if local.x >= left && local.x <= right {
                let others = slots.filter { $0.id != id }
                if SettingsStore.shared.current.rows > 1, let hit = slots.firstIndex(where: { $0.rect.contains(local) }) {
                    let hitID = slots[hit].id
                    let index = hitID == id ? (BarController.shared.trayDrag?.index ?? 0) : (others.firstIndex { $0.id == hitID } ?? 0)
                    wanted = TrayDragPreview(id: id, index: index)
                } else {
                    wanted = TrayDragPreview(id: id, index: others.filter { $0.rect.midX < local.x }.count)
                }
            }
        }
        guard wanted != BarController.shared.trayDrag else { return }
        BarController.shared.trayDrag = wanted
        BarController.shared.redraw()
    }

    // Holding a bar item over the chevron opens the flyout, so it can be dropped inside.
    private func watchChevron(at point: NSPoint) {
        guard source == .bar, !TrayOverflowPanel.shared.isOpen, let (view, rect) = chevron(at: point) else {
            chevronTimer?.invalidate()
            chevronTimer = nil
            return
        }
        guard chevronTimer == nil else { return }
        let anchor = view.screenRect(rect)
        chevronTimer = Timer.scheduledTimer(withTimeInterval: TrayDrag.chevronDelay, repeats: false) { _ in
            MainActor.assumeIsolated {
                let drag = TrayDrag.shared
                drag.chevronTimer = nil
                guard drag.active, !TrayOverflowPanel.shared.isOpen else { return }
                TrayOverflowPanel.shared.toggle(above: anchor, bar: view)
            }
        }
    }
}
