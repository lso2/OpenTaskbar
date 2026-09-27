// WindowActions.swift
// Raises, restores and minimizes another application's windows through accessibility.
// Exists so launcher clicks and preview tiles act on one specific window.
// Defines: WindowActions
// Notes: docs/notes/app/Sources/OpenTaskbar/Windows/WindowActions.swift.md
import AppKit
import ApplicationServices

@MainActor
enum WindowActions {
    static func raise(_ window: WindowInfo) {
        let ref = window.ref
        NSRunningApplication(processIdentifier: window.pid)?.activate()
        Task { @AXActor in
            if AX.bool(ref, kAXMinimizedAttribute) == true {
                AX.set(ref, kAXMinimizedAttribute, kCFBooleanFalse)
            }
            AX.set(ref, kAXMainAttribute, kCFBooleanTrue)
            AX.perform(ref, kAXRaiseAction)
        }
    }

    static func minimize(_ window: WindowInfo) {
        let ref = window.ref
        Task { @AXActor in
            AX.set(ref, kAXMinimizedAttribute, kCFBooleanTrue)
        }
    }

    // Minimizes whichever window the application reports as focused.
    static func minimizeFocused(of pid: pid_t) {
        Task { @AXActor in
            let app = AX.application(pid)
            guard let window = AX.element(app, kAXFocusedWindowAttribute) ?? AX.element(app, kAXMainWindowAttribute) else { return }
            AX.set(window, kAXMinimizedAttribute, kCFBooleanTrue)
        }
    }
}
