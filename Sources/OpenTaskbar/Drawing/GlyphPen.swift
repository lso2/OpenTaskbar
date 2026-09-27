// GlyphPen.swift
// Stroke, fill and arc helpers shared by every glyph, in the bar's flipped coordinates.
// Exists so glyph code states geometry once and never repeats path setup.
// Defines: GlyphPen, GlyphGrid
// Notes: docs/notes/app/Sources/OpenTaskbar/Drawing/GlyphPen.swift.md
import AppKit

// A 24 unit grid laid over an icon box. Windows draws a 16 point icon as 24 pixels at 150
// percent, so one unit is one of those pixels and glyphs keep the measured geometry.
struct GlyphGrid {
    let origin: NSPoint
    let unit: CGFloat

    init(box: NSRect) {
        origin = box.origin
        unit = box.width / 24
    }

    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + (x * unit), y: origin.y + (y * unit)) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: origin.x + (x * unit), y: origin.y + (y * unit), width: w * unit, height: h * unit)
    }
    func len(_ value: CGFloat) -> CGFloat { value * unit }
    var stroke: CGFloat { unit }
}

enum GlyphPen {
    static func line(_ from: NSPoint, _ to: NSPoint, width: CGFloat, color: NSColor) {
        polyline([from, to], width: width, color: color)
    }

    static func polyline(_ points: [NSPoint], width: CGFloat, color: NSColor, closed: Bool = false) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        if closed { path.close() }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    static func fillPolygon(_ points: [NSPoint], color: NSColor) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        path.close()
        color.setFill()
        path.fill()
    }

    static func strokeRect(_ rect: NSRect, radius: CGFloat, width: CGFloat, color: NSColor) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    static func fillRect(_ rect: NSRect, radius: CGFloat = 0, color: NSColor) {
        color.setFill()
        if radius > 0 {
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        } else {
            NSBezierPath(rect: rect).fill()
        }
    }

    static func strokeCircle(center: NSPoint, radius: CGFloat, width: CGFloat, color: NSColor) {
        let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                               width: radius * 2, height: radius * 2))
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    static func fillCircle(center: NSPoint, radius: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2)).fill()
    }

    // An open arc, angles in degrees measured clockwise from twelve o'clock, as hs.canvas
    // measured them. The bar view is flipped, so y grows downward.
    static func arc(center: NSPoint, radius: CGFloat, from start: CGFloat, to end: CGFloat,
                    width: CGFloat, color: NSColor) {
        var sweep = end - start
        if sweep <= 0 { sweep += 360 }
        let steps = max(8, Int(sweep / 6))
        var points: [NSPoint] = []
        for step in 0...steps {
            let degrees = start + (sweep * CGFloat(step) / CGFloat(steps))
            let radians = degrees * .pi / 180
            points.append(NSPoint(x: center.x + (radius * sin(radians)),
                                  y: center.y - (radius * cos(radians))))
        }
        polyline(points, width: width, color: color)
    }
}
