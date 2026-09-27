// StatusGlyphTests.swift
// Checks that a captured status item window is cut down to its glyph and sorted into one-color or colored.
// Exists so the tray draws menu bar glyphs at the tray icon size, in the bar's ink or in their own colors.
// Defines: StatusGlyphTests
// Notes: docs/notes/app/Tests/OpenTaskbarTests/StatusGlyphTests.swift.md
import AppKit
import Testing
@testable import OpenTaskbar

@MainActor
struct StatusGlyphTests {
    // A 40 by 30 point window at 2x with a 10 by 12 point mark in the middle, like a menu bar item.
    private func capture(_ color: NSColor) -> NSImage {
        let size = NSSize(width: 40, height: 30)
        let bitmap = BarRenderer.bitmap(size: size, scale: 2) {
            color.setFill()
            NSRect(x: 15, y: 9, width: 10, height: 12).fill()
        }
        let image = NSImage(size: size)
        if let bitmap { image.addRepresentation(bitmap) }
        return image
    }

    @Test func paddingIsTrimmedToTheMark() {
        let glyph = StatusItemGlyphs.prepare(capture(.white))
        #expect(abs(glyph.image.size.width - 10) < 0.6)
        #expect(abs(glyph.image.size.height - 12) < 0.6)
    }

    @Test func grayMarksAreOneColor() {
        #expect(StatusItemGlyphs.prepare(capture(.white)).monochrome)
    }

    @Test func coloredMarksKeepTheirColors() {
        #expect(!StatusItemGlyphs.prepare(capture(NSColor(red: 0.85, green: 0.45, blue: 0.3, alpha: 1))).monochrome)
    }
}
