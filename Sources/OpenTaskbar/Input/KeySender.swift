// KeySender.swift
// Posts a synthetic key press and release with given modifiers.
// Exists so every module that sends keystrokes marks its events the same way.
// Defines: KeySender
// Notes: docs/notes/app/Sources/OpenTaskbar/Input/KeySender.swift.md
import CoreGraphics

enum KeySender {
    // Written into each posted event's user data field, so OpenTaskbar's own taps pass them through.
    static let marker: Int64 = 0x42_6F_74_74_6F_6D

    static func stroke(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.post(tap: .cghidEventTap)
        }
    }

    // Keyboard shortcut key codes used across the modules.
    static let space: CGKeyCode = 49
    static let escape: CGKeyCode = 53
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126
    static let home: CGKeyCode = 115
    static let end: CGKeyCode = 119
    static let v: CGKeyCode = 9
    static let three: CGKeyCode = 20
    static let four: CGKeyCode = 21
    static let five: CGKeyCode = 23
}
