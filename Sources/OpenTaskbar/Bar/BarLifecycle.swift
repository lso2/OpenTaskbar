// BarLifecycle.swift
// Refits and redraws the bars when screens change, the Space changes, or the Mac wakes or unlocks.
// Exists as the port of bottombar-lifecycle.lua, whose rebuild on every wake the native panel no longer needs.
// Defines: BarLifecycle
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarLifecycle.swift.md
import AppKit

@MainActor
enum BarLifecycle {
    static func start() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BarController.shared.refit() }
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                Log.bar.debug("space changed")
                BarController.shared.redraw()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + WindowList.confirmDelay) {
                MainActor.assumeIsolated { WindowList.shared.refreshAll() }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { note in
                let event = note.name.rawValue
                MainActor.assumeIsolated { BarLifecycle.settle(event) }
            }
        }
        DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                                                            object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { BarLifecycle.settle("unlock") }
        }
    }

    // A moment for the display to finish coming back before the frames are read.
    private static func settle(_ event: String) {
        Log.bar.info("settling after \(event, privacy: .public)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            MainActor.assumeIsolated {
                BarController.shared.refit()
                BarController.shared.redraw()
                AudioControl.output.refresh()
                AudioControl.input.refresh()
                Battery.shared.refresh()
                WiFi.shared.refresh()
            }
        }
    }
}
