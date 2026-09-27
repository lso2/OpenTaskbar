// BarGlyphs.swift
// The marks the bar draws itself, each authored on a 24 unit grid and drawn into any square box.
// Exists so every drawn mark keeps the one-pixel stroke weight of the Windows 10 taskbar glyphs.
// Defines: BarGlyph
// Notes: docs/notes/app/Sources/OpenTaskbar/Drawing/BarGlyphs.swift.md
import AppKit

enum BarGlyph: Equatable {
    case displayOff
    case folder
    case calculator
    case search
    case spotlight
    case controlCenter
    case chevron
    case microphone(muted: Bool)
    case tools
    case displayBrightness
    case keyboardBrightness
    case taskView
    case notifications
    case pagerUp
    case pagerDown

    func draw(in box: NSRect, color: NSColor) {
        let g = GlyphGrid(box: box)
        let w = g.stroke
        switch self {
        case .displayOff:
            GlyphPen.strokeRect(g.rect(2.5, 4.5, 19, 12), radius: g.len(1), width: w, color: color)
            GlyphPen.line(g.p(12, 16.5), g.p(12, 19.5), width: w, color: color)
            GlyphPen.line(g.p(7.5, 19.5), g.p(16.5, 19.5), width: w, color: color)

        case .folder:
            GlyphPen.polyline([g.p(2.5, 5.5), g.p(9, 5.5), g.p(11, 7.5), g.p(21.5, 7.5), g.p(21.5, 19.5), g.p(2.5, 19.5)],
                              width: w, color: color, closed: true)
            GlyphPen.line(g.p(2.5, 10.5), g.p(21.5, 10.5), width: w, color: color)

        case .calculator:
            GlyphPen.strokeRect(g.rect(5.5, 2.5, 13, 19), radius: g.len(1), width: w, color: color)
            GlyphPen.strokeRect(g.rect(8.5, 5.5, 7, 3), radius: 0, width: w, color: color)
            for row in 0..<3 {
                for column in 0..<3 {
                    GlyphPen.fillRect(g.rect(8 + (CGFloat(column) * 3), 11 + (CGFloat(row) * 3), 2, 2), color: color)
                }
            }

        case .search:
            GlyphPen.strokeCircle(center: g.p(13.5, 10.5), radius: g.len(6.5), width: w, color: color)
            GlyphPen.line(g.p(8.9, 15.1), g.p(3.5, 20.5), width: w * 1.5, color: color)

        case .spotlight:
            GlyphPen.strokeCircle(center: g.p(10.5, 10.5), radius: g.len(6.5), width: w, color: color)
            GlyphPen.line(g.p(15.1, 15.1), g.p(20.5, 20.5), width: w * 1.5, color: color)

        case .controlCenter:
            GlyphPen.strokeRect(g.rect(2.5, 4, 19, 7), radius: g.len(3.5), width: w, color: color)
            GlyphPen.fillCircle(center: g.p(18, 7.5), radius: g.len(2.2), color: color)
            GlyphPen.strokeRect(g.rect(2.5, 13, 19, 7), radius: g.len(3.5), width: w, color: color)
            GlyphPen.fillCircle(center: g.p(6, 16.5), radius: g.len(2.2), color: color)

        case .chevron:
            GlyphPen.polyline([g.p(4.5, 16), g.p(12.5, 7.5), g.p(20.5, 16)], width: w, color: color)

        case .microphone(let muted):
            GlyphPen.strokeRect(g.rect(9.5, 3.5, 5, 10), radius: g.len(2.5), width: w, color: color)
            GlyphPen.arc(center: g.p(12, 10.5), radius: g.len(5.5), from: 90, to: 270, width: w, color: color)
            GlyphPen.line(g.p(12, 16), g.p(12, 19.5), width: w, color: color)
            GlyphPen.line(g.p(8.5, 19.5), g.p(15.5, 19.5), width: w, color: color)
            if muted { GlyphPen.line(g.p(4.5, 20.5), g.p(19.5, 3.5), width: w * 1.5, color: color) }

        case .tools:
            GlyphPen.strokeCircle(center: g.p(12, 12), radius: g.len(3), width: w, color: color)
            GlyphPen.strokeCircle(center: g.p(12, 12), radius: g.len(7), width: w, color: color)
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                GlyphPen.line(g.p(12 + (cos(angle) * 7), 12 + (sin(angle) * 7)),
                              g.p(12 + (cos(angle) * 9.5), 12 + (sin(angle) * 9.5)), width: w * 2.5, color: color)
            }

        case .displayBrightness:
            GlyphPen.strokeCircle(center: g.p(12, 12), radius: g.len(3.5), width: w, color: color)
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                GlyphPen.line(g.p(12 + (cos(angle) * 6.5), 12 + (sin(angle) * 6.5)),
                              g.p(12 + (cos(angle) * 9.5), 12 + (sin(angle) * 9.5)), width: w, color: color)
            }

        case .keyboardBrightness:
            GlyphPen.strokeRect(g.rect(3.5, 12.5, 17, 7), radius: g.len(1), width: w, color: color)
            for column in 0..<4 {
                GlyphPen.fillRect(g.rect(6 + (CGFloat(column) * 3.5), 15, 1.5, 1.5), color: color)
            }
            for (x, lean) in [(CGFloat(7), CGFloat(-1.5)), (12, 0), (17, 1.5)] {
                GlyphPen.line(g.p(x, 9.5), g.p(x + lean, 5.5), width: w, color: color)
            }

        case .taskView:
            GlyphPen.strokeRect(g.rect(2.5, 5.5, 8, 6), radius: 0, width: w, color: color)
            GlyphPen.strokeRect(g.rect(13.5, 5.5, 8, 6), radius: 0, width: w, color: color)
            GlyphPen.strokeRect(g.rect(6.5, 14.5, 11, 6), radius: 0, width: w, color: color)

        case .notifications:
            GlyphPen.polyline([g.p(8, 19), g.p(0.5, 19), g.p(0.5, 1), g.p(23.5, 1), g.p(23.5, 19), g.p(16, 19),
                               g.p(12, 23), g.p(8, 19)], width: w, color: color)

        case .pagerUp:
            GlyphPen.polyline([g.p(7, 14), g.p(12, 9), g.p(17, 14)], width: w * 1.5, color: color)

        case .pagerDown:
            GlyphPen.polyline([g.p(7, 10), g.p(12, 15), g.p(17, 10)], width: w * 1.5, color: color)
        }
    }

    // The Start launcher: an image when one is chosen, otherwise a four pane window in perspective
    // whose left edge is shorter than its right, fitted to the box width.
    static func drawLauncher(in box: NSRect, image: NSImage?, color: NSColor) {
        if let image {
            let fitted = aspectFit(image.size, in: box)
            image.draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            return
        }

        let paneWidth = box.width
        let leftHeight = box.width * (15.0 / 24.0)
        let rightHeight = box.width * (20.0 / 24.0)
        let halfGap = box.width * (1.25 / 24.0)
        let centerY = box.midY
        func edge(_ at: CGFloat) -> CGFloat { leftHeight + ((rightHeight - leftHeight) * (at / paneWidth)) }

        for (left, right) in [(CGFloat(0), (paneWidth / 2) - halfGap), ((paneWidth / 2) + halfGap, paneWidth)] {
            GlyphPen.fillPolygon([
                NSPoint(x: box.minX + left, y: centerY - (edge(left) / 2)),
                NSPoint(x: box.minX + right, y: centerY - (edge(right) / 2)),
                NSPoint(x: box.minX + right, y: centerY - halfGap),
                NSPoint(x: box.minX + left, y: centerY - halfGap),
            ], color: color)
            GlyphPen.fillPolygon([
                NSPoint(x: box.minX + left, y: centerY + halfGap),
                NSPoint(x: box.minX + right, y: centerY + halfGap),
                NSPoint(x: box.minX + right, y: centerY + (edge(right) / 2)),
                NSPoint(x: box.minX + left, y: centerY + (edge(left) / 2)),
            ], color: color)
        }
    }

    static func aspectFit(_ size: NSSize, in box: NSRect) -> NSRect {
        guard size.width > 0, size.height > 0 else { return box }
        let ratio = min(box.width / size.width, box.height / size.height)
        let width = size.width * ratio
        let height = size.height * ratio
        return NSRect(x: box.midX - (width / 2), y: box.midY - (height / 2), width: width, height: height)
    }

    // A square box of side size centered on a point.
    static func box(center: NSPoint, size: CGFloat) -> NSRect {
        NSRect(x: center.x - (size / 2), y: center.y - (size / 2), width: size, height: size)
    }
}
