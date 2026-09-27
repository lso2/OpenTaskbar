// KeyboardBacklight.swift
// Reads and sets the built-in keyboard's backlight through CoreBrightness.
// Exists because the Lua build could only estimate the level from the step keys it sent.
// Defines: KeyboardBacklight
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/KeyboardBacklight.swift.md
import Foundation
import PrivateAPI

@MainActor
final class KeyboardBacklight {
    static let shared = KeyboardBacklight()

    private let client = KeyboardBrightnessClient()

    // The backlight id is a per-machine number, 95158913 on the development Mac, so it is read.
    private lazy var keyboardID: UInt64? = {
        let ids = (client.copyKeyboardBacklightIDs() as? [NSNumber])?.map(\.uint64Value) ?? []
        return ids.first { client.isKeyboardBuilt(in: $0) } ?? ids.first
    }()

    // 0 to 100, or nil on a Mac with no backlit keyboard.
    var level: Double? {
        guard let keyboardID else { return nil }
        return Double(client.brightness(forKeyboard: keyboardID)) * 100
    }

    func set(_ percent: Double) {
        guard let keyboardID else { return }
        client.setBrightness(Float(min(100, max(0, percent)) / 100), forKeyboard: keyboardID)
    }

    var summary: String {
        guard let level else { return "No keyboard backlight" }
        return "Keyboard brightness   \(Int(level.rounded(.down)))%"
    }
}
