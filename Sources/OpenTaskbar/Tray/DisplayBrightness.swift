// DisplayBrightness.swift
// Reads and sets the built-in display's brightness through DisplayServices.
// Exists because Apple Silicon panels publish their brightness through no public API.
// Defines: DisplayBrightness
// Notes: docs/notes/app/Sources/OpenTaskbar/Tray/DisplayBrightness.swift.md
import CoreGraphics
import PrivateAPI

@MainActor
enum DisplayBrightness {
    // The built-in panel when it is active, otherwise the main display.
    static var display: CGDirectDisplayID {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count = UInt32(0)
        if CGGetActiveDisplayList(16, &ids, &count) == .success {
            for id in ids.prefix(Int(count)) where CGDisplayIsBuiltin(id) != 0 { return id }
        }
        return CGMainDisplayID()
    }

    // 0 to 100, or nil when the display offers no brightness control.
    static var level: Double? {
        var value = Float(0)
        guard DisplayServicesGetBrightness(display, &value) == 0 else { return nil }
        return Double(value) * 100
    }

    static func set(_ percent: Double) {
        _ = DisplayServicesSetBrightness(display, Float(min(100, max(0, percent)) / 100))
    }

    static var summary: String {
        guard let level else { return "Screen brightness unavailable" }
        return "Screen brightness   \(Int(level.rounded(.down)))%"
    }
}
