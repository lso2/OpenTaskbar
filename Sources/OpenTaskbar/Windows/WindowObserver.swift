// WindowObserver.swift
// Registers an AXObserver on every regular application and refreshes its window list on each change.
// Exists so the bar hears about windows created, closed, minimized, restored and retitled as they happen.
// Defines: WindowObserver
// Notes: docs/notes/app/Sources/OpenTaskbar/Windows/WindowObserver.swift.md
import AppKit
import ApplicationServices

@MainActor
final class WindowObserver {
    static let shared = WindowObserver()

    // An AXObserver is a CF object the SDK leaves non-Sendable; it is created on AXActor and
    // afterwards only kept alive here.
    private struct Box: @unchecked Sendable { let observer: AXObserver }

    nonisolated static let notifications = [
        kAXWindowCreatedNotification, kAXUIElementDestroyedNotification,
        kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification,
        kAXTitleChangedNotification, kAXFocusedWindowChangedNotification,
    ]

    private var observers: [pid_t: Box] = [:]
    private var listeners: [@MainActor (pid_t, String) -> Void] = []
    private var started = false

    func listen(_ listener: @escaping @MainActor (pid_t, String) -> Void) {
        listeners.append(listener)
    }

    func start() {
        guard !started else { return }
        started = true

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            observe(app.processIdentifier)
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.activationPolicy == .regular else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { WindowObserver.shared.observe(pid) }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { WindowObserver.shared.stop(pid) }
        }
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { WindowList.shared.refresh(pid) }
        }
    }

    func observe(_ pid: pid_t) {
        guard AXIsProcessTrusted(), observers[pid] == nil else { return }
        Task { @AXActor in
            guard let box = WindowObserver.makeObserver(pid) else { return }
            await MainActor.run {
                Log.windows.debug("observing pid \(pid)")
                WindowObserver.shared.observers[pid] = box
                WindowList.shared.refresh(pid)
            }
        }
    }

    private func stop(_ pid: pid_t) {
        if let box = observers.removeValue(forKey: pid) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(box.observer), .defaultMode)
        }
        WindowList.shared.forget(pid)
        for listener in listeners { listener(pid, kAXUIElementDestroyedNotification) }
    }

    fileprivate func changed(_ pid: pid_t, _ notification: String) {
        WindowList.shared.refresh(pid)
        for listener in listeners { listener(pid, notification) }
    }

    @AXActor
    private static func makeObserver(_ pid: pid_t) -> Box? {
        var created: AXObserver?
        guard AXObserverCreate(pid, windowObserverCallback, &created) == .success, let observer = created else { return nil }
        let app = AX.application(pid)
        // The pid travels in the refcon's pointer bits; pid 0 never reaches here.
        let refcon = UnsafeMutableRawPointer(bitPattern: Int(pid))
        for name in notifications {
            AXObserverAddNotification(observer, app.element, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        return Box(observer: observer)
    }
}

// Runs on the main run loop, where makeObserver placed the observer's source.
private func windowObserverCallback(_ observer: AXObserver, _ element: AXUIElement,
                                    _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    let pid = pid_t(Int(bitPattern: refcon))
    let name = notification as String
    MainActor.assumeIsolated { WindowObserver.shared.changed(pid, name) }
}
