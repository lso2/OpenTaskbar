// LaunchChecks.swift
// Detects a launch from an App Translocation path and offers to move OpenTaskbar into Applications.
// Exists because Hammerspoon's login item was registered to a translocated path on the development Mac.
// Defines: LaunchChecks
// Notes: docs/notes/app/Sources/OpenTaskbar/App/LaunchChecks.swift.md
import AppKit
import PrivateAPI

@MainActor
enum LaunchChecks {
    static var isTranslocated: Bool {
        Bundle.main.bundlePath.contains("/AppTranslocation/")
    }

    // Returns true when the app is relaunching from Applications and this copy should do nothing more.
    static func offerMoveIfTranslocated() -> Bool {
        guard isTranslocated else { return false }
        let alert = NSAlert()
        alert.messageText = "OpenTaskbar is running from a temporary location"
        alert.informativeText = "macOS opened it from a read-only copy. Move it to the Applications folder so it keeps its permissions and starts at login."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        guard let original = SecTranslocateCreateOriginalPathForURL(Bundle.main.bundleURL as CFURL, nil)?
            .takeRetainedValue() as URL? else {
            Log.app.info("original path of the translocated bundle not found")
            return false
        }
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(original.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.moveItem(at: original, to: destination)
            removexattr(destination.path, "com.apple.quarantine", XATTR_NOFOLLOW)
        } catch {
            let failure = NSAlert()
            failure.messageText = "OpenTaskbar could not be moved: \(error.localizedDescription)"
            failure.runModal()
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }
}
