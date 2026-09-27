// BarRenderer.swift
// Paints a computed bar layout into the current graphics context.
// Exists so the live bar view and the snapshot tests draw through the same code.
// Defines: BarRenderer
// Notes: docs/notes/app/Sources/OpenTaskbar/Bar/BarRenderer.swift.md
import AppKit

@MainActor
enum BarRenderer {
    // The context must be flipped, with y growing downward, as the bar view is.
    static func draw(_ layout: BarLayoutResult, palette: BarPalette, bounds: NSRect, hovered: BarZoneKind?) {
        palette.fill.setFill()
        bounds.fill(using: .copy)

        if let hovered, hovered.highlightsOnHover, let zone = layout.zones.last(where: { $0.kind == hovered }) {
            palette.hoverFill.setFill()
            zone.rect.fill(using: .sourceOver)
        }
        for mark in layout.marks { draw(mark) }
    }

    static func draw(_ mark: BarMark) {
        switch mark {
        case .launcher(let box, let image, let color):
            BarGlyph.drawLauncher(in: box, image: image, color: color)
        case .glyph(let glyph, let box, let color):
            glyph.draw(in: box, color: color)
        case .tray(let glyph, let box, let color):
            glyph.draw(in: box, color: color)
        case .text(let string, let point):
            string.draw(at: point)
        case .image(let image, let rect):
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        case .tinted(let image, let rect, let color):
            // The captured glyph's alpha becomes a mask filled with the bar's ink.
            guard let context = NSGraphicsContext.current?.cgContext,
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            context.saveGState()
            context.translateBy(x: 0, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            let flipped = NSRect(x: rect.minX, y: 0, width: rect.width, height: rect.height)
            context.clip(to: flipped, mask: cgImage)
            color.setFill()
            context.fill(flipped)
            context.restoreGState()
        case .fill(let rect, let color):
            color.setFill()
            rect.fill(using: .sourceOver)
        }
    }

    // A PNG of the layout at the given pixel scale, for the snapshot tests.
    static func png(_ layout: BarLayoutResult, palette: BarPalette, size: NSSize, scale: CGFloat) -> Data? {
        bitmap(size: size, scale: scale) {
            draw(layout, palette: palette, bounds: NSRect(origin: .zero, size: size), hovered: nil)
        }?.representation(using: .png, properties: [:])
    }

    // A bitmap drawn in the bar's flipped coordinates, for snapshots and drag images.
    static func bitmap(size: NSSize, scale: CGFloat, drawing: () -> Void) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                            pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0),
              let base = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        let cg = base.cgContext
        cg.scaleBy(x: scale, y: scale)
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        drawing()
        NSGraphicsContext.restoreGraphicsState()
        bitmap.size = size
        return bitmap
    }
}
