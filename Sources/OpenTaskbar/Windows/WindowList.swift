// WindowList.swift
// Keeps each running application's standard windows, minimized ones included, for the bar to read.
// Exists so drawing reads window counts from memory while the accessibility reads happen on AXActor.
// Defines: WindowInfo, WindowList
// Notes: docs/notes/app/Sources/OpenTaskbar/Windows/WindowList.swift.md
import AppKit
import ApplicationServices

struct WindowInfo: Sendable, Equatable {
    let ref: AXRef
    let pid: pid_t
    let title: String
    let minimized: Bool
    let windowID: CGWindowID?
    let frame: CGRect?
}

@MainActor
final class WindowList {
    static let shared = WindowList()

    private(set) var windows: [pid_t: [WindowInfo]] = [:]
    private var pending: Set<pid_t> = []
    private var observers: [@MainActor (pid_t) -> Void] = []

    func windows(for pid: pid_t) -> [WindowInfo] { windows[pid] ?? [] }

    func count(for pid: pid_t) -> Int { windows[pid]?.count ?? 0 }

    func observe(_ observer: @escaping @MainActor (pid_t) -> Void) {
        observers.append(observer)
    }

    // One read in flight per application; a burst of notifications collapses into it.
    func refresh(_ pid: pid_t) {
        guard AXIsProcessTrusted(), !pending.contains(pid) else { return }
        pending.insert(pid)
        Task { @AXActor in
            let found = WindowList.read(pid)
            await MainActor.run {
                WindowList.shared.pending.remove(pid)
                WindowList.shared.store(found, for: pid)
            }
        }
    }

    func forget(_ pid: pid_t) {
        guard windows.removeValue(forKey: pid) != nil else { return }
        for observer in observers { observer(pid) }
    }

    // A read taken while the system switches Spaces can come back empty for an app that still
    // has windows, so a drop to none is read again before anything else relies on it.
    nonisolated static let confirmDelay: TimeInterval = 0.6

    func refreshAll() {
        for pid in windows.keys { refresh(pid) }
    }

    private func store(_ found: [WindowInfo], for pid: pid_t) {
        if found.isEmpty, (windows[pid]?.count ?? 0) > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + WindowList.confirmDelay) {
                MainActor.assumeIsolated { WindowList.shared.refresh(pid) }
            }
        }
        guard windows[pid] != found else { return }
        let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        Log.windows.debug("\(name, privacy: .public): \(found.count) standard windows")
        windows[pid] = found
        for observer in observers { observer(pid) }
    }

    @AXActor
    static func read(_ pid: pid_t) -> [WindowInfo] {
        let app = AX.application(pid)
        return AX.elements(app, kAXWindowsAttribute).compactMap { window in
            guard AX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole else { return nil }
            return WindowInfo(ref: window, pid: pid,
                              title: AX.string(window, kAXTitleAttribute) ?? "",
                              minimized: AX.bool(window, kAXMinimizedAttribute) ?? false,
                              windowID: AX.windowID(window),
                              frame: AX.frame(window))
        }
    }
}
