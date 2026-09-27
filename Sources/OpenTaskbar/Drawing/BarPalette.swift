// BarPalette.swift
// Derives the bar's fill, ink, underline and highlight colors and its fonts from the current settings.
// Exists so every drawing routine reads colors and type sizes from one computation.
// Defines: BarPalette
// Notes: docs/notes/app/Sources/OpenTaskbar/Drawing/BarPalette.swift.md
import AppKit

struct BarPalette {
    let fill: NSColor
    let text: NSColor
    let bright: NSColor
    let dim: NSColor
    let underline: NSColor
    let activeFill: NSColor
    let hoverFill: NSColor
    let showDesktopLine: NSColor
    let fontSize: CGFloat
    let clockFontSize: CGFloat
    let lightBar: Bool

    // The system menu bar's own size, so menu titles at 100 percent match the top bar.
    static var baseFontSize: CGFloat {
        let size = NSFont.menuBarFont(ofSize: 0).pointSize
        return size > 0 ? size : 13
    }

    init(_ settings: BarSettings) {
        let level = CGFloat(settings.brightness / 100)
        let alpha = settings.transparencyOn ? 1 - CGFloat(settings.transparency / 100) : 1
        let textScale = CGFloat(settings.textScale / 100)
        lightBar = level > 0.55
        fill = NSColor(calibratedRed: level, green: level, blue: level, alpha: alpha)
        text = NSColor(white: lightBar ? 0 : 1, alpha: lightBar ? 0.88 : 1)
        bright = NSColor(white: lightBar ? 0 : 1, alpha: 1)
        dim = NSColor(white: lightBar ? 0 : 1, alpha: lightBar ? 0.62 : 0.7)
        // Measured on the Windows 10 taskbar: underline #B3B2AF, active button #333333 on black,
        // Show Desktop edge #666666.
        underline = lightBar ? NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.29, alpha: 1)
                             : NSColor(calibratedRed: 179 / 255, green: 178 / 255, blue: 175 / 255, alpha: 1)
        activeFill = NSColor(white: lightBar ? 0 : 1, alpha: 0.2)
        hoverFill = NSColor(white: lightBar ? 0 : 1, alpha: 0.1)
        showDesktopLine = NSColor(white: lightBar ? 0.55 : 0.4, alpha: 1)
        fontSize = min(44, max(8, BarPalette.baseFontSize * textScale))
        clockFontSize = min(40, max(8, TaskbarMetrics.clockFontSize * textScale))
    }

    var regularFont: NSFont { NSFont.menuBarFont(ofSize: fontSize) }
    var boldFont: NSFont { NSFont.boldSystemFont(ofSize: fontSize) }
    var clockFont: NSFont { NSFont.systemFont(ofSize: clockFontSize) }
}
