// LowPowerMode.swift
// Reads and switches the system's Low Power Mode.
// Exists as the Low Power Mode switch of the battery flyout.
// Defines: LowPowerMode
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/LowPowerMode.swift.md
import Foundation

enum LowPowerMode {
    static var isOn: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    // pmset needs administrator rights, so macOS asks for the password. The answer is whether
    // the command ran; the new state is read back from the system afterward.
    static func set(_ on: Bool) async -> Bool {
        await Task.detached {
            let source = "do shell script \"/usr/bin/pmset -a lowpowermode \(on ? 1 : 0)\" with administrator privileges"
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            return error == nil
        }.value
    }
}
