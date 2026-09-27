// ClockPreference.swift
// Reads and writes the system-wide 12 or 24 hour setting, AppleICUForce24HourTime.
// Exists because the Lua build changed the real system flag, and the port keeps that behavior.
// Defines: ClockPreference
// Notes: docs/notes/app/Sources/OpenTaskbar/Settings/ClockPreference.swift.md
import Foundation

enum ClockPreference {
    static var key: CFString { "AppleICUForce24HourTime" as CFString }

    static var hour24: Bool {
        let value = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return (value as? Bool) ?? false
    }

    // The same domain `defaults write NSGlobalDomain` writes to.
    static func setHour24(_ on: Bool) {
        CFPreferencesSetValue(key, on as CFBoolean, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleTimePreferencesChangedNotification"), object: nil,
            userInfo: nil, deliverImmediately: true)
    }
}
