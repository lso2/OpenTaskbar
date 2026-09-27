// TrayGlyphs.swift
// The volume, Wi-Fi and battery marks, drawn from live state on the 24 unit grid.
// Exists with the geometry measured from the Windows 10 notification area at 150 percent.
// Defines: TrayGlyph
// Notes: docs/notes/app/Sources/OpenTaskbar/Drawing/TrayGlyphs.swift.md
import AppKit

enum TrayGlyph: Equatable {
    case volume(level: Double, muted: Bool)
    case wifi(connected: Bool, powered: Bool, bars: Int)
    case battery(percent: Double, charging: Bool, plugged: Bool)

    // Parts that are off, such as the waves above the current volume, draw at this strength.
    static let unlit: CGFloat = 0.3

    func draw(in box: NSRect, color: NSColor) {
        let g = GlyphGrid(box: box)
        let w = g.stroke
        let dim = color.withAlphaComponent(color.alphaComponent * TrayGlyph.unlit)

        switch self {
        case .volume(let level, let muted):
            GlyphPen.polyline([g.p(2, 9), g.p(6, 9), g.p(10, 4), g.p(10, 21), g.p(6, 16), g.p(2, 16)],
                              width: w, color: color, closed: true)
            if muted || level <= 0 {
                GlyphPen.line(g.p(14, 10), g.p(19, 15), width: w, color: color)
                GlyphPen.line(g.p(19, 10), g.p(14, 15), width: w, color: color)
                return
            }
            let lit = level > 66 ? 3 : level > 33 ? 2 : 1
            for (index, wave) in [(CGFloat(4.5), CGFloat(34)), (8, 43), (12, 45)].enumerated() {
                GlyphPen.arc(center: g.p(10, 12.5), radius: g.len(wave.0), from: 90 - wave.1, to: 90 + wave.1,
                             width: w, color: index < lit ? color : dim)
            }

        case .wifi(let connected, let powered, let bars):
            let lit = (connected && powered) ? max(1, min(3, bars)) : 0
            for (index, radius) in [CGFloat(7), 12, 17].enumerated() {
                GlyphPen.arc(center: g.p(21, 22), radius: g.len(radius), from: 270, to: 360,
                             width: w, color: index < lit ? color : dim)
            }
            GlyphPen.fillCircle(center: g.p(20, 21), radius: g.len(1.5), color: lit > 0 ? color : dim)

        case .battery(let percent, let charging, let plugged):
            let level = CGFloat(min(100, max(0, percent))) / 100
            let fillColor = charging ? NSColor(calibratedRed: 0.3, green: 0.8, blue: 0.4, alpha: 0.95) : color
            if plugged {
                GlyphPen.line(g.p(4, 4), g.p(4, 6.5), width: w, color: color)
                GlyphPen.line(g.p(8, 4), g.p(8, 6.5), width: w, color: color)
                GlyphPen.polyline([g.p(3, 7), g.p(9, 7), g.p(9, 11), g.p(6, 13), g.p(3, 11)], width: w, color: color, closed: true)
                GlyphPen.line(g.p(6, 13), g.p(6, 19.5), width: w, color: color)
                GlyphPen.polyline([g.p(11, 7), g.p(25, 7), g.p(25, 19), g.p(8, 19), g.p(8, 13)], width: w, color: color)
                GlyphPen.fillRect(g.rect(10.5, 8.5, 13 * level, 9), color: fillColor)
            } else {
                GlyphPen.strokeRect(g.rect(3, 7, 22, 12), radius: 0, width: w, color: color)
                GlyphPen.fillRect(g.rect(4.5, 8.5, 19 * level, 9), color: fillColor)
            }
            GlyphPen.fillRect(g.rect(25.5, 11.5, 2, 3), color: color)
        }
    }
}
