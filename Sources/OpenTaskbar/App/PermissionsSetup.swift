// PermissionsSetup.swift
// The first-launch walk through Accessibility, Input Monitoring, Screen Recording and Location, and its window.
// Exists so granting takes one button, three switches and one Allow, with each page opened in turn.
// Defines: PermissionsSetup
// Notes: docs/notes/app/Sources/OpenTaskbar/App/PermissionsSetup.swift.md
import AppKit
import SwiftUI

@MainActor
@Observable
final class PermissionsSetup {
    static let shared = PermissionsSetup()
    static let required: [Permissions.Grant] = [.accessibility, .inputMonitoring, .screenRecording, .location]

    // Set while the walk runs, so a Quit & Reopen from System Settings resumes it on the next launch.
    private static let runningKey = "permissionsSetupRunning"

    private(set) var granted: [Permissions.Grant: Bool] = [:]
    private(set) var current: Permissions.Grant?

    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var changed = false

    var missing: [Permissions.Grant] { Self.required.filter { granted[$0] != true } }

    private init() {}

    func showIfNeeded() {
        read()
        guard !missing.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.runningKey)
            return
        }
        show()
        if UserDefaults.standard.bool(forKey: Self.runningKey) { advance() }
    }

    func show() {
        read()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        startPolling()
    }

    // Continue, and Open Page Again while a page is waiting on its switch.
    func start() {
        UserDefaults.standard.set(true, forKey: Self.runningKey)
        advance()
    }

    func later() {
        UserDefaults.standard.removeObject(forKey: Self.runningKey)
        current = nil
        stopPolling()
        window?.orderOut(nil)
    }

    // The request adds OpenTaskbar to the page's list, and the page opens with its switch in view.
    // Location asks in its own Allow dialog the first time; after a refusal only its page can change it.
    private func advance() {
        guard let next = missing.first else {
            finish()
            return
        }
        current = next
        let firstAsk = next == .location && WiFi.shared.locationStatus == .notDetermined
        Permissions.request(next)
        if !firstAsk { Permissions.openPane(next) }
    }

    private func finish() {
        UserDefaults.standard.removeObject(forKey: Self.runningKey)
        current = nil
        stopPolling()
        window?.orderOut(nil)
        // Event taps and capture streams made before the grants only start working in a new process.
        if changed { StartContextMenu.relaunch() }
    }

    private func read() {
        var states: [Permissions.Grant: Bool] = [:]
        for grant in Self.required { states[grant] = Permissions.granted(grant) }
        if !granted.isEmpty && states != granted { changed = true }
        if states != granted { granted = states }
    }

    private func poll() {
        read()
        guard let current else { return }
        if granted[current] == true { advance() }
    }

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { PermissionsSetup.shared.poll() }
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "OpenTaskbar Permissions"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.contentView = NSHostingView(rootView: PermissionsSetupView(setup: self))
        window.center()
        // The close button ends the walk the same way Later does.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { PermissionsSetup.shared.later() }
        }
        return window
    }
}
