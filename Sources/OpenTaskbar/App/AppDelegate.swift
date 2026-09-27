// AppDelegate.swift
// Starts every part of OpenTaskbar in order once the application has launched.
// Exists as the one place that shows what runs at startup and in which order.
// Defines: AppDelegate
// Notes: docs/notes/app/Sources/OpenTaskbar/App/AppDelegate.swift.md
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if LaunchChecks.offerMoveIfTranslocated() { return }

        HammerspoonImporter.importOnce()
        LoginItem.apply()

        AudioControl.output.start()
        AudioControl.input.start()
        Battery.shared.start()
        WiFi.shared.start()
        WindowObserver.shared.start()
        AppMenuReader.shared.start()

        BarController.shared.start()
        BarLifecycle.start()
        BarAutoHide.shared.start()
        StartKeyTap.shared.start()
        ChromiumAccessibility.start()
        ModuleHost.apply()
        SettingsStore.shared.observe { ModuleHost.apply() }
        Updater.shared.start()
        PermissionsSetup.shared.showIfNeeded()

        Log.app.info("OpenTaskbar started from \(Bundle.main.bundlePath, privacy: .public)")
        for grant in Permissions.Grant.allCases {
            Log.app.info("\(grant.rawValue, privacy: .public) granted: \(Permissions.granted(grant))")
        }
    }

    // Opening the app again while it runs shows Settings, since it has no Dock icon or window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return false
    }
}
