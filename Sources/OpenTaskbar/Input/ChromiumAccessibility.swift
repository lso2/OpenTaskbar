// ChromiumAccessibility.swift
// Turns on the accessibility tree of Chromium and Electron apps as they launch.
// Exists because those apps publish no tree until asked, so a text field in a web page reads as nothing.
// Defines: ChromiumAccessibility
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/ChromiumAccessibility.swift.md
import AppKit

@MainActor
enum ChromiumAccessibility {
    static let bundles: Set<String> = [
        "com.brave.Browser", "com.google.Chrome", "com.microsoft.edgemac", "com.vivaldi.Vivaldi",
        "company.thebrowser.Browser", "com.microsoft.VSCode", "com.spotify.client", "com.tinyspeck.slackmacgap",
    ]

    private static var started = false

    static func start() {
        guard !started else { return }
        started = true
        for app in NSWorkspace.shared.runningApplications { enable(app) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                                                          object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            let bundle = app.bundleIdentifier
            MainActor.assumeIsolated { enable(pid: pid, bundle: bundle) }
        }
    }

    private static func enable(_ app: NSRunningApplication) {
        enable(pid: app.processIdentifier, bundle: app.bundleIdentifier)
    }

    // AXManualAccessibility is the attribute Chromium watches for; unlike AXEnhancedUserInterface
    // it leaves window animations alone.
    private static func enable(pid: pid_t, bundle: String?) {
        guard let bundle, bundles.contains(bundle), AXIsProcessTrusted() else { return }
        Task { @AXActor in
            AX.set(AX.application(pid), "AXManualAccessibility", kCFBooleanTrue)
        }
    }
}
