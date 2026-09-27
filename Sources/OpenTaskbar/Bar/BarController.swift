// BarController.swift
// Owns one BarPanel per screen, gathers the live state the bars draw, and redraws them on every change.
// Exists so the tray, window, menu and settings modules report to one place that repaints every bar.
// Defines: BarController
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarController.swift.md
import AppKit

@MainActor
final class BarController {
    static let shared = BarController()

    private(set) var panels: [BarPanel] = []
    private(set) var currentLaunchers: [LauncherEntry] = []
    var page = 0
    // The tray item being dragged, drawn where it would land.
    var trayDrag: TrayDragPreview?
    var pageCount = 1
    private var runningOrder: [pid_t] = []
    private var minuteTimer: Timer?
    private var scanTimer: Timer?

    func start() {
        buildPanels()

        let redraw: @MainActor () -> Void = { BarController.shared.redraw() }
        SettingsStore.shared.observe { BarController.shared.settingsChanged() }
        AudioControl.output.observe(redraw)
        AudioControl.input.observe(redraw)
        Battery.shared.observe(redraw)
        WiFi.shared.observe(redraw)
        AppMenuReader.shared.observe(redraw)
        StatusItemMirror.shared.observe(redraw)
        WindowList.shared.observe { _ in BarController.shared.redraw() }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    StatusItemMirror.shared.invalidate()
                    BarController.shared.redraw()
                }
            }
        }

        scheduleMinuteTimer()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            MainActor.assumeIsolated {
                StatusItemMirror.shared.scan()
                BarController.shared.redraw()
            }
        }
        StatusItemMirror.shared.scan()
    }

    // The clock changes on the minute, so the redraw is aligned to it.
    private func scheduleMinuteTimer() {
        let now = Date()
        let next = Calendar.current.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
            ?? now.addingTimeInterval(60)
        let timer = Timer(fire: next, interval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { BarController.shared.redraw() }
        }
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    func buildPanels() {
        for panel in panels { panel.orderOut(nil) }
        panels = NSScreen.screens.map { BarPanel(screen: $0) }
        BarAutoHide.shared.panelsRebuilt()
    }

    func refit() {
        let wanted = Set(NSScreen.screens.map(BarPanel.displayID(of:)))
        if wanted != Set(panels.map(\.displayID)) {
            buildPanels()
        } else {
            for panel in panels { panel.fit() }
        }
    }

    private func settingsChanged() {
        for panel in panels { panel.fit() }
        redraw()
    }

    func redraw() {
        for panel in panels { panel.barView.needsDisplay = true }
    }

    func panel(for view: NSView) -> BarPanel? {
        panels.first { $0.barView === view }
    }

    // MARK: State the layout reads

    func inputs(width: CGFloat) -> BarInputs {
        let settings = SettingsStore.shared.current
        currentLaunchers = launchers(settings)
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return BarInputs(
            settings: settings,
            palette: BarPalette(settings),
            metrics: TaskbarMetrics(settings),
            width: width,
            startIcon: StartIconStore.currentImage(for: settings.startIconName),
            launchers: currentLaunchers,
            menuTitles: AppMenuReader.shared.pid == front ? AppMenuReader.shared.menus.map(\.title) : [],
            volume: AudioControl.output.state,
            microphone: AudioControl.input.state,
            battery: Battery.shared.state,
            wifi: WiFi.shared.state,
            wifiBars: WiFi.shared.bars ?? 0,
            statusItems: StatusItemMirror.shared.tiles,
            hour24: ClockPreference.hour24,
            now: Date(),
            page: page,
            trayDrag: trayDrag)
    }

    // Pinned launchers first, then running apps that are not pinned, in the order they first appeared.
    private func launchers(_ settings: BarSettings) -> [LauncherEntry] {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let trusted = AXIsProcessTrusted()
        var entries: [LauncherEntry] = []
        var pinnedPaths = Set<String>()

        func windowed(_ app: NSRunningApplication?) -> Bool {
            guard let app else { return false }
            return trusted ? WindowList.shared.count(for: app.processIdentifier) > 0 : true
        }

        if settings.shows("pinned") {
            for launcher in PinnedStore.launchers() {
                let app = PinnedStore.runningApp(for: launcher.path)
                let hasWindows = windowed(app)
                pinnedPaths.insert(URL(fileURLWithPath: launcher.path).standardizedFileURL.path)
                entries.append(LauncherEntry(launcher: launcher, pinned: true, hasWindows: hasWindows,
                                             active: hasWindows && app?.processIdentifier == front))
            }
        }

        guard settings.shows("running") else { return entries }
        let own = ProcessInfo.processInfo.processIdentifier
        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.processIdentifier != own && app.bundleURL != nil
                && !pinnedPaths.contains(app.bundleURL!.standardizedFileURL.path)
        }
        let alive = Set(running.map(\.processIdentifier))
        runningOrder.removeAll { !alive.contains($0) }
        for app in running where !runningOrder.contains(app.processIdentifier) { runningOrder.append(app.processIdentifier) }

        for pid in runningOrder {
            guard let app = running.first(where: { $0.processIdentifier == pid }), windowed(app),
                  let url = app.bundleURL else { continue }
            let launcher = Launcher(path: url.path, title: app.localizedName ?? PinnedStore.title(for: url.path),
                                    icon: app.icon ?? PinnedStore.icon(for: url.path))
            entries.append(LauncherEntry(launcher: launcher, pinned: false, hasWindows: true, active: pid == front))
        }
        return entries
    }
}
