// StartPanel.swift
// The window that holds the Start panel: placement at the launcher, keyboard focus, and dismissal.
// Exists so the Start panel takes typing for its search field without activating OpenTaskbar.
// Defines: StartPanel, StartWindow, StartModel
// Notes: docs/notes/app/Sources/OpenTaskbar/Start/StartPanel.swift.md
import AppKit
import SwiftUI

// A non-activating panel that can still become key, which is what lets the search field take typing.
final class StartWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
@Observable
final class StartModel {
    enum Field { case displayName, thisMacLabel }

    var apps: [CatalogApp] = []
    var query = ""
    var showAll = false
    var showPower = false
    var editing: Field?
    var draft = ""
    var focusToken = 0
    var settings = SettingsStore.shared.current

    var visibleApps: [CatalogApp] {
        let term = query.trimmingCharacters(in: .whitespaces).lowercased()
        return apps.filter { app in
            if !term.isEmpty { return app.title.lowercased().contains(term) }
            return showAll || !app.system
        }
    }
}

@MainActor
final class StartPanel {
    static let shared = StartPanel()

    private let window: StartWindow
    private let effect = NSVisualEffectView()
    private let model = StartModel()
    private var monitors: [Any] = []
    private(set) var isOpen = false

    private init() {
        window = StartWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        // Below popup menus, so a menu opened from the bar draws in front of the panel.
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        let container = NSView()
        effect.blendingMode = .behindWindow
        effect.material = .hudWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        container.addSubview(effect)
        let host = NSHostingView(rootView: StartPanelView(model: model))
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        window.contentView = container

        SettingsStore.shared.observe { StartPanel.shared.model.settings = SettingsStore.shared.current }
    }

    func toggle(from bar: BarView) {
        if isOpen {
            close()
            return
        }
        guard let panel = bar.window as? BarPanel, let screen = panel.screenNow else { return }
        open(on: screen, barTop: panel.frame.maxY)
    }

    // The bar's search button: Start with its search field focused, left open when it already is.
    func openSearch(from bar: BarView) {
        if isOpen {
            model.focusToken += 1
            return
        }
        toggle(from: bar)
    }

    // Opened by the modifier tap: the screen under the pointer, with its bar brought out of hiding.
    func openAtPointer() {
        if isOpen {
            close()
            return
        }
        let mouse = NSEvent.mouseLocation
        let panel = BarController.shared.panels.first { $0.screenNow?.frame.contains(mouse) ?? false }
            ?? BarController.shared.panels.first
        guard let panel, let screen = panel.screenNow else { return }
        BarAutoHide.shared.reveal(panel)
        open(on: screen, barTop: panel.frame.maxY)
    }

    private func open(on screen: NSScreen, barTop: CGFloat) {
        let settings = SettingsStore.shared.current
        model.settings = settings
        model.apps = AppCatalog.load()
        model.query = ""
        model.showAll = false
        model.showPower = false
        model.editing = nil

        // The panel grows with the type, up to the maxima in Settings and never past the screen.
        let scale = max(1, CGFloat(settings.panelFontScale / 100))
        let area = screen.visibleFrame
        let width = min((480 * scale).rounded(.down), CGFloat(settings.panelMaxWidth), area.width - 8)
        let height = min((620 * scale).rounded(.down), CGFloat(settings.panelMaxHeight), area.maxY - barTop - 6)
        window.setFrame(NSRect(x: area.minX, y: barTop, width: width, height: height), display: true)
        effect.frame = window.contentView?.bounds ?? .zero
        effect.isHidden = !settings.panelBlur
        effect.appearance = NSAppearance(named: settings.panelBrightness > 55 ? .aqua : .darkAqua)

        window.makeKeyAndOrderFront(nil)
        isOpen = true
        model.focusToken += 1
        watchOutsideClicks()
        BarController.shared.redraw()
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        window.orderOut(nil)
    }

    // Clicks on the bar are left to the bar, which closes the panel for anything but the launcher.
    private func watchOutsideClicks() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { StartPanel.shared.close() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            MainActor.assumeIsolated {
                let panel = StartPanel.shared
                if event.window !== panel.window && !(event.window is BarPanel) && event.window?.level != .popUpMenu {
                    panel.close()
                }
            }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    // MARK: Actions the view calls

    func launch(_ path: String) {
        close()
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func power(_ action: PowerActions.Action) {
        close()
        PowerActions.perform(action)
    }

    func rename(_ field: StartModel.Field, to value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        SettingsStore.shared.update { settings in
            switch field {
            case .displayName: settings.displayName = trimmed
            case .thisMacLabel: settings.thisMacLabel = trimmed
            }
        }
    }
}
