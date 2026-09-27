// PopupPanel.swift
// The borderless panel every flyout above the bar uses: placement over an anchor, every Space, dismissal on outside clicks.
// Exists so the slider, calendar, tools and tray flyouts share one window setup and one dismissal rule.
// Defines: PopupPanel
// Notes: docs/notes/app/Sources/OpenTaskbar/Panels/PopupPanel.swift.md
import AppKit

@MainActor
final class PopupPanel: NSPanel {
    private static var openPanels: [ObjectIdentifier: PopupPanel] = [:]
    static var anyOpen: Bool { !openPanels.isEmpty }

    // Opening one flyout closes the others, as the Lua bar's panels closed on the next click.
    static func dismissAll(except kept: PopupPanel) {
        for panel in openPanels.values where panel !== kept && panel.exclusive { panel.dismiss() }
    }

    // Tooltips and previews set this false: they come and go without closing a flyout.
    var exclusive = true
    // Set by flyouts with a text field, so typing reaches the field without activating OpenTaskbar.
    var takesKeyboard = false

    private var monitors: [Any] = []
    private(set) var isOpen = false
    private(set) weak var bar: BarView?
    // Run after the panel goes away, by panels that stop work such as live previews.
    var onDismiss: (@MainActor () -> Void)?

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
    }

    override var canBecomeKey: Bool { takesKeyboard }

    // Centered over the anchor, kept on the anchor's screen, gap points above the bar's top edge.
    func present(size: NSSize, above anchor: NSRect, bar: BarView, gap: CGFloat = 4) {
        self.bar = bar
        let barTop = bar.window?.frame.maxY ?? anchor.maxY
        let screen = bar.window?.screen?.frame ?? NSScreen.main?.frame ?? .zero
        let x = min(max(screen.minX + 4, anchor.midX - (size.width / 2)), screen.maxX - size.width - 4)
        setFrame(NSRect(x: x, y: barTop + gap, width: size.width, height: size.height), display: true)
        orderFrontRegardless()
        guard !isOpen else { return }
        if exclusive { PopupPanel.dismissAll(except: self) }
        isOpen = true
        PopupPanel.openPanels[ObjectIdentifier(self)] = self

        // A click in another app arrives through the global monitor; a click in another
        // OpenTaskbar window arrives through the local one. Clicks on the bar leave it to the bar.
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { self.dismiss() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            MainActor.assumeIsolated {
                if event.window !== self && !(event.window is BarPanel) { self.dismiss() }
            }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    func dismiss() {
        guard isOpen else { return }
        isOpen = false
        PopupPanel.openPanels.removeValue(forKey: ObjectIdentifier(self))
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        orderOut(nil)
        onDismiss?()
    }
}
