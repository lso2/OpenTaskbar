// SpotlightLauncher.swift
// Opens the system Spotlight search from the tray's Spotlight item.
// Exists so the tray item sends the Spotlight shortcut the user has set, read from the system's hotkey list.
// Defines: SpotlightLauncher
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/SpotlightLauncher.swift.md
import AppKit
import ApplicationServices

@MainActor
enum SpotlightLauncher {
    // Entry 64 of com.apple.symbolichotkeys is "Show Spotlight search". Absent means never changed,
    // which is Command+Space.
    static func shortcut() -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
        guard let entry = hotkeys?["64"] as? [String: Any] else { return (KeySender.space, .maskCommand) }
        guard (entry["enabled"] as? Bool) ?? ((entry["enabled"] as? Int) == 1) else { return nil }
        guard let value = entry["value"] as? [String: Any], let parameters = value["parameters"] as? [Int],
              parameters.count == 3 else { return (KeySender.space, .maskCommand) }
        return (CGKeyCode(parameters[1]), CGEventFlags(rawValue: UInt64(parameters[2])))
    }

    static func open() {
        if let shortcut = shortcut() {
            KeySender.stroke(keyCode: shortcut.keyCode, flags: shortcut.flags)
            return
        }
        // The shortcut is switched off, so Spotlight's own menu bar item is pressed instead.
        guard AXIsProcessTrusted(),
              let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Spotlight").first?.processIdentifier
        else { return }
        Task { @AXActor in
            let app = AX.application(pid)
            guard let extras = AX.element(app, kAXExtrasMenuBarAttribute),
                  let item = AX.elements(extras, kAXChildrenAttribute).first else {
                Log.tray.info("spotlight has no menu bar item and no shortcut")
                return
            }
            let result = AX.performResult(item, kAXPressAction)
            Log.tray.info("spotlight press: AXError \(result.rawValue)")
        }
    }
}
